#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "rubygems"
require "rubygems/package"
require "tmpdir"

def need(k)
  ENV.fetch(k) { abort "missing #{k}" }
end

root = need("NOKOGIRI_ANDROID_ROOT")
plat = need("GEM_PLATFORM")
minor = need("RUBY_MINOR")
so = ARGV[0] || "#{root}/out/#{plat}/nokogiri.so"
abort "missing #{so}" unless File.file?(so)
src = File.directory?("#{root}/nokogiri/lib") ? "#{root}/nokogiri" : root
ver = File.read("#{src}/lib/nokogiri/version/constant.rb")[/VERSION = "([^"]+)"/, 1] || abort("version")

files = Dir.chdir(src) do
  Dir.glob("lib/**/*").reject { |p| File.directory?("#{src}/#{p}") || p.include?("/jruby/") || p.end_with?(".jar") }
end

pkg = "#{root}/pkg"
FileUtils.mkdir_p(pkg)
gem_path = "#{pkg}/nokogiri-#{ver}-#{plat}.gem"

Dir.mktmpdir("noko-") do |stage|
  files.each do |rel|
    FileUtils.mkdir_p(File.dirname("#{stage}/#{rel}"))
    FileUtils.cp("#{src}/#{rel}", "#{stage}/#{rel}")
  end
  so_rel = "lib/nokogiri/#{minor}/nokogiri.so"
  FileUtils.mkdir_p(File.dirname("#{stage}/#{so_rel}"))
  FileUtils.cp(so, "#{stage}/#{so_rel}")
  files << so_rel
  %w[LICENSE.md LICENSE-DEPENDENCIES.md].each do |d|
    next unless File.file?("#{src}/#{d}")
    FileUtils.cp("#{src}/#{d}", "#{stage}/#{d}")
    files << d
  end
  File.write("#{stage}/NOKOGIRI_ANDROID.txt", "nokogiri-android #{ver} #{plat}\n")
  files << "NOKOGIRI_ANDROID.txt"
  files = files.uniq.sort

  spec = Gem::Specification.new do |s|
    s.name = "nokogiri"
    s.version = ver
    s.platform = Gem::Platform.new(plat)
    s.summary = "Nokogiri for Android (#{plat})"
    s.authors = ["nokogiri-android"]
    s.email = "nokogiri-talk@googlegroups.com"
    s.homepage = "https://github.com/gouravkhunger/nokogiri-android"
    s.license = "MIT"
    s.required_ruby_version = ">= 3.1.0"
    s.files = files
    s.require_paths = ["lib"]
    s.extensions = []
    s.metadata = { "nokogiri_android" => "true", "android_abi_platform" => plat }
    s.add_runtime_dependency "racc", "~> 1.4"
  end

  Dir.chdir(stage) { FileUtils.mv(Gem::Package.build(spec), gem_path) }
end
puts "OK #{gem_path}"
