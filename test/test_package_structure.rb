#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "rbconfig"

ROOT = File.expand_path("..", __dir__)

class TestPackage < Minitest::Test
  def test_package_and_verify
    Dir.mktmpdir do |tmp|
      so = "#{tmp}/nokogiri.so"
      File.binwrite(so, ([0x7f, 0x45, 0x4c, 0x46, 2, 1, 1] + [0] * 64).pack("C*"))
      env = {
        "NOKOGIRI_ANDROID_ROOT" => ROOT,
        "GEM_PLATFORM" => "aarch64-linux-android",
        "RUBY_MINOR" => "3.4",
      }
      assert system(env, RbConfig.ruby, "#{ROOT}/scripts/package.rb", so)
      gem = Dir.glob("#{ROOT}/pkg/nokogiri-*-aarch64-linux-android.gem").max_by { |p| File.mtime(p) }
      assert gem
      assert system(RbConfig.ruby, "#{ROOT}/scripts/verify.rb", gem)
    end
  end
end
