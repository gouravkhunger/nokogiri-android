#!/usr/bin/env ruby
# frozen_string_literal: true

require "rubygems/package"
require "tmpdir"

gem = ARGV[0] or abort "usage: verify.rb <gem>"
pkg = Gem::Package.new(gem)
s = pkg.spec
abort "name" unless s.name == "nokogiri"
abort "extensions=#{s.extensions}" unless s.extensions.empty?
abort "ruby platform" if s.platform == Gem::Platform::RUBY
sos = s.files.grep(%r{\Alib/nokogiri/\d+\.\d+/nokogiri\.so\z})
abort "no .so" if sos.empty?
Dir.mktmpdir do |d|
  pkg.extract_files(d)
  sos.each do |rel|
    path = "#{d}/#{rel}"
    abort "missing #{rel}" unless File.file?(path)
    abort "not ELF" unless File.binread(path, 4) == "\x7fELF"
  end
end
puts "OK #{gem} platform=#{s.platform}"
