#!/usr/bin/env ruby
# frozen_string_literal: true

# Build a precompiled Android platform gem for Nokogiri.
# Layout matches upstream fat gems: lib/nokogiri/<ruby_minor>/nokogiri.so
# extensions cleared so install never compiles on device.

require "fileutils"
require "rubygems"
require "rubygems/package"
require "tmpdir"

def need!(key)
  val = ENV[key]
  abort "missing env #{key}" if val.nil? || val.empty?
  val
end

root = need!("NOKOGIRI_ANDROID_ROOT")
gem_platform = need!("GEM_PLATFORM")
ruby_minor = need!("RUBY_MINOR")
so_path = ARGV[0] || File.join(root, "out", gem_platform, "nokogiri.so")
abort "missing native extension: #{so_path}" unless File.file?(so_path)

nokogiri_src = if File.directory?(File.join(root, "nokogiri", "lib"))
  File.join(root, "nokogiri")
elsif File.directory?(File.join(root, "lib", "nokogiri"))
  root
else
  abort "cannot find nokogiri lib/ under #{root}"
end

version_file = File.join(nokogiri_src, "lib/nokogiri/version/constant.rb")
version = File.read(version_file)[/VERSION = "([^"]+)"/, 1]
abort "could not parse Nokogiri::VERSION" unless version

pkg_dir = File.join(root, "pkg")
FileUtils.mkdir_p(pkg_dir)

lib_root = File.join(nokogiri_src, "lib")
files = Dir.chdir(nokogiri_src) do
  Dir.glob("lib/**/*").reject do |p|
    File.directory?(File.join(nokogiri_src, p)) ||
      p.include?("/jruby/") ||
      p.end_with?(".jar")
  end
end

gem_name = "nokogiri-#{version}-#{gem_platform}.gem"
gem_path = File.join(pkg_dir, gem_name)

Dir.mktmpdir("nokogiri-android-gem-") do |stage|
  files.each do |rel|
    dest = File.join(stage, rel)
    FileUtils.mkdir_p(File.dirname(dest))
    FileUtils.cp(File.join(nokogiri_src, rel), dest)
  end

  so_rel = "lib/nokogiri/#{ruby_minor}/nokogiri.so"
  so_dest = File.join(stage, so_rel)
  FileUtils.mkdir_p(File.dirname(so_dest))
  FileUtils.cp(so_path, so_dest)
  files << so_rel

  %w[LICENSE.md LICENSE-DEPENDENCIES.md].each do |doc|
    src = File.join(nokogiri_src, doc)
    next unless File.file?(src)

    FileUtils.cp(src, File.join(stage, doc))
    files << doc
  end

  marker = <<~MARK
    # nokogiri-android

    Precompiled Nokogiri #{version} for Android (#{gem_platform}).
    Built with Android NDK for JekyllEx / Termux-style Ruby.
    Install with: gem install --local #{gem_name}
    No on-device C compiler required.
  MARK
  File.write(File.join(stage, "NOKOGIRI_ANDROID.txt"), marker)
  files << "NOKOGIRI_ANDROID.txt"

  if File.file?(File.join(root, "INSTALL.md"))
    FileUtils.cp(File.join(root, "INSTALL.md"), File.join(stage, "INSTALL-ANDROID.md"))
    files << "INSTALL-ANDROID.md"
  end

  files = files.uniq.sort

  spec = Gem::Specification.new do |s|
    s.name = "nokogiri"
    s.version = version
    s.platform = Gem::Platform.new(gem_platform)
    s.summary = "Nokogiri precompiled for Android (#{gem_platform}) — nokogiri-android"
    s.description = <<~DESC
      Precompiled native Nokogiri gem for Android ABIs, distributed as nokogiri-android.
      Contains a prebuilt C extension so installation does not require compiling on device.
      Intended for JekyllEx / Termux-style Android Ruby environments.
    DESC
    s.authors = ["nokogiri-android maintainers"]
    s.email = "nokogiri-talk@googlegroups.com"
    s.homepage = "https://github.com/gouravkhunger/nokogiri-android"
    s.license = "MIT"
    s.required_ruby_version = ">= 3.1.0"
    s.files = files
    s.require_paths = ["lib"]
    s.extensions = [] # critical: no on-device compile
    s.metadata = {
      "homepage_uri" => "https://github.com/gouravkhunger/nokogiri-android",
      "source_code_uri" => "https://github.com/gouravkhunger/nokogiri-android",
      "nokogiri_android" => "true",
      "android_abi_platform" => gem_platform,
      "ruby_api_minor" => ruby_minor,
    }
    s.add_runtime_dependency("racc", "~> 1.4")
  end

  FileUtils.rm_f(gem_path)
  Dir.chdir(stage) do
    built_name = Gem::Package.build(spec)
    built_path = File.expand_path(built_name)
    FileUtils.mv(built_path, gem_path)
  end

  puts "OK: #{gem_path}"
  puts "platform=#{spec.platform}"
  puts "files=#{spec.files.size}"
  puts "extensions=#{spec.extensions.inspect}"
  puts "native=#{so_rel}"
end
