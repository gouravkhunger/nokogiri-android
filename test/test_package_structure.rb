#!/usr/bin/env ruby
# frozen_string_literal: true

# Drives the real packaging scripts with a synthetic Android ELF stub
# so packaging + verify paths are tested without a full NDK compile.

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "rbconfig"

ROOT = File.expand_path("..", __dir__)

def synthetic_aarch64_elf
  # Minimal ELF64 little-endian ET_DYN EM_AARCH64 header (enough for magic/verify)
  bytes = [
    0x7f, 0x45, 0x4c, 0x46, # magic
    2,                      # ELFCLASS64
    1,                      # ELFDATA2LSB
    1,                      # EV_CURRENT
    0,                      # ELFOSABI_NONE
    0, 0, 0, 0, 0, 0, 0, 0, # padding
    0x03, 0x00,             # e_type = ET_DYN
    0xb7, 0x00,             # e_machine = EM_AARCH64
    0x01, 0x00, 0x00, 0x00, # e_version
  ]
  # pad to 64-byte ELF64 header + a little payload
  bytes += [0] * (64 - bytes.length) if bytes.length < 64
  bytes += [0] * 64
  bytes.pack("C*")
end

class TestPackageStructure < Minitest::Test
  def test_package_gem_produces_prebuilt_android_gem
    Dir.mktmpdir("noko-pkg-test-") do |tmp|
      so_dir = File.join(tmp, "out", "aarch64-linux-android")
      FileUtils.mkdir_p(so_dir)
      so_path = File.join(so_dir, "nokogiri.so")
      File.binwrite(so_path, synthetic_aarch64_elf)

      env = {
        "NOKOGIRI_ANDROID_ROOT" => ROOT,
        "GEM_PLATFORM" => "aarch64-linux-android",
        "RUBY_MINOR" => "3.4",
      }

      pkg_dir = File.join(ROOT, "pkg")
      FileUtils.mkdir_p(pkg_dir)
      before = Dir.glob(File.join(pkg_dir, "nokogiri-*-aarch64-linux-android.gem"))

      ok = system(env, RbConfig.ruby, File.join(ROOT, "scripts/package_gem.rb"), so_path)
      assert ok, "package_gem.rb failed"

      after = Dir.glob(File.join(pkg_dir, "nokogiri-*-aarch64-linux-android.gem"))
      built = (after - before).max_by { |p| File.mtime(p) } || after.max_by { |p| File.mtime(p) }
      assert built && File.file?(built), "expected platform gem under pkg/"

      verify = system(RbConfig.ruby, File.join(ROOT, "scripts/verify_gem.rb"), built)
      assert verify, "verify_gem.rb failed for #{built}"

      unpack_dir = File.join(tmp, "unpack")
      FileUtils.mkdir_p(unpack_dir)
      assert system("gem", "unpack", built, "--target", unpack_dir), "gem unpack failed"
      unpacked = Dir.glob(File.join(unpack_dir, "nokogiri-*")).first
      assert unpacked, "unpack dir missing"
      so = Dir.glob(File.join(unpacked, "lib/nokogiri/*/nokogiri.so")).first
      assert so && File.file?(so), "unpacked gem missing versioned nokogiri.so"
      assert_equal "\x7fELF", File.binread(so, 4)

      # gem install --local with extensions empty should not compile
      install_dir = File.join(tmp, "gem_home")
      FileUtils.mkdir_p(install_dir)
      # Use --install-dir; ignore platform mismatch on host Darwin
      cmd = [
        "gem", "install", "--local", built,
        "--install-dir", install_dir,
        "--no-document",
        "--force",
      ]
      # On non-android hosts, may need ignore dependencies and force
      installed = system(*cmd, exception: false)
      # Even if platform reject happens, unpack path already proved no-compile layout.
      # Prefer success when rubygems allows foreign platform.
      if installed
        installed_so = Dir.glob(File.join(install_dir, "gems/**/lib/nokogiri/*/nokogiri.so")).first
        assert installed_so, "install dir missing prebuilt so"
        # ensure no extensions build directory required
        ext_builds = Dir.glob(File.join(install_dir, "extensions/**/*"))
        # extensions dir may be empty or absent — must not contain compiled artifacts from build
        refute ext_builds.any? { |p| p.end_with?(".o") }, "unexpected object files from compile"
      else
        # Record that host refused foreign platform; layout still valid
        warn "note: host gem install refused platform gem (expected on darwin); layout checks passed"
      end
    end
  end
end
