#!/usr/bin/env ruby
# frozen_string_literal: true

# Structural verification that a nokogiri-android gem is prebuilt
# (no on-device compile) and ships an Android native extension.

require "rubygems"
require "rubygems/package"
require "tmpdir"
require "fileutils"

gem_path = ARGV[0] or abort "usage: #{$PROGRAM_NAME} <gemfile>"
abort "missing #{gem_path}" unless File.file?(gem_path)

package = Gem::Package.new(gem_path)
spec = package.spec
errors = []

puts "gem=#{gem_path}"
puts "name=#{spec.name} version=#{spec.version} platform=#{spec.platform}"
puts "extensions=#{spec.extensions.inspect}"
puts "files=#{spec.files.size}"

errors << "expected name nokogiri, got #{spec.name}" unless spec.name == "nokogiri"
errors << "extensions must be empty for prebuilt gem, got #{spec.extensions.inspect}" unless spec.extensions.nil? || spec.extensions.empty?
errors << "platform must not be ruby (prebuilt android)" if spec.platform == Gem::Platform::RUBY

so_files = spec.files.grep(%r{\Alib/nokogiri/\d+\.\d+/nokogiri\.so\z})
errors << "missing lib/nokogiri/X.Y/nokogiri.so in gem files" if so_files.empty?

has_marker = spec.files.include?("NOKOGIRI_ANDROID.txt") ||
  (spec.metadata && spec.metadata["nokogiri_android"] == "true")
errors << "missing nokogiri-android identity marker/metadata" unless has_marker

has_mini = spec.dependencies.any? { |d| d.name == "mini_portile2" }
errors << "prebuilt gem should not depend on mini_portile2" if has_mini

# Unpack and check .so magic / ELF
Dir.mktmpdir("verify-gem-") do |dir|
  package.extract_files(dir)
  so_files.each do |rel|
    path = File.join(dir, rel)
    errors << "listed so missing on disk: #{rel}" unless File.file?(path)
    next unless File.file?(path)
    magic = File.binread(path, 4)
    # ELF magic
    errors << "#{rel} is not ELF (got #{magic.inspect})" unless magic == "\x7fELF"
    puts "so=#{rel} size=#{File.size(path)} elf=yes"
    if system("which", "file", out: File::NULL, err: File::NULL)
      system("file", path)
    end
    if system("which", "readelf", out: File::NULL, err: File::NULL)
      system("readelf", "-h", path)
      system("readelf", "-d", path)
    end
  end
end

if errors.any?
  warn "VERIFY FAILED:"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end

puts "VERIFY OK"
