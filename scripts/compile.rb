#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "rbconfig"

def need(k)
  ENV.fetch(k) { abort "missing #{k}" }
end

stage = need("STAGE_DIR")
plat = need("GEM_PLATFORM")
api = need("RUBY_API")
root = need("NOKOGIRI_ANDROID_ROOT")
target = need("TARGET")
cc = need("CC")
cxx = need("CXX")
ar = need("AR")
real_cc = need("NOKOGIRI_ANDROID_REAL_CC")
ruby_hdr = need("RUBY_HDR")
ruby_arch_hdr = need("RUBY_ARCH_HDR")
host_ruby = RbConfig.ruby
ranlib = ENV.fetch("RANLIB")
strip = ENV.fetch("STRIP")

src = File.directory?(File.join(root, "nokogiri", "ext", "nokogiri")) ? File.join(root, "nokogiri") : root
ext = File.join(src, "ext", "nokogiri")
abort "no ext" unless File.directory?(ext)

%w[Makefile nokogiri.so mkmf.log].each { |f| FileUtils.rm_f(File.join(ext, f)) }
Dir.glob(File.join(ext, "*.{o,so}")).each { |f| FileUtils.rm_f(f) }
FileUtils.rm_rf(File.join(ext, "tmp"))
FileUtils.rm_rf(File.join(src, "ports")) if ENV["CLEAN_PORTS"] == "1"

rbc = Dir.glob(File.join(stage, "lib", "ruby", api, "*", "rbconfig.rb")).find { |p| p.include?("linux-android") }
abort "no rbconfig" unless rbc

preload = File.join(stage, "preload.rb")
FileUtils.cp(File.join(root, "scripts/preload.rb"), preload)
child = ENV.to_h.merge(
  "NOKO_RBC" => rbc,
  "NOKO_STAGE" => stage,
  "NOKO_TARGET" => target,
  "NOKO_CC" => cc,
  "NOKO_CXX" => cxx,
  "NOKO_REAL_CC" => real_cc,
  "NOKO_AR" => ar,
  "NOKO_RANLIB" => ranlib,
  "NOKO_STRIP" => strip,
  "NOKO_RUBY_HDR" => ruby_hdr,
  "NOKO_RUBY_ARCH_HDR" => ruby_arch_hdr,
  "NOKO_HOST_RUBY" => host_ruby,
  "NOKO_CPPFLAGS" => ENV.fetch("CPPFLAGS", ""),
  "NOKO_LDFLAGS" => ENV.fetch("LDFLAGS", ""),
  "NOKO_CFLAGS" => ENV.fetch("CFLAGS", "-fPIC -O2"),
)

begin
  require "mini_portile2"
rescue LoadError
  system(host_ruby, "-S", "gem", "install", "mini_portile2", "--no-document") || abort("mini_portile2")
  Gem.clear_paths
  require "mini_portile2"
end

args = [
  "--disable-clean",
  "--enable-static",
  "--enable-cross-build",
  "--prevent-strip",
  "--srcdir=#{ext}",
]

Dir.chdir(ext) do
  abort "extconf" unless system(child, host_ruby, "-r", preload, "extconf.rb", *args)
  mk = File.read("Makefile")
  mk.gsub!(/^RUBY\s*=.*$/, "RUBY = #{host_ruby}")
  mk.gsub!(/^ruby\s*=.*$/, "ruby = #{host_ruby}")
  mk.gsub!(/^all: clean-ports\n/, "all: $(DLLIB)\n")
  mk.gsub!(/^clean-ports:.*\n(?:\t.*\n)*/, "")
  File.write("Makefile", mk)
  abort "empty DLLIB" unless mk.match?(/^DLLIB\s*=\s*\S+/)
  abort "make" unless system(ENV.fetch("MAKE", "make"), "-j#{ENV.fetch("JOBS", "4")}")
end

so = Dir.glob(File.join(ext, "**", "nokogiri.so")).first || abort("no .so")
out = File.join(root, "out", plat)
FileUtils.mkdir_p(out)
dest = File.join(out, "nokogiri.so")
FileUtils.cp(so, dest)
system(strip, "--strip-unneeded", dest) if File.executable?(strip)

readelf = File.join(File.dirname(ar), "llvm-readelf")
readelf = "readelf" unless File.executable?(readelf)
if system("which", readelf.split.first, out: File::NULL, err: File::NULL) || File.executable?(readelf)
  needed = `#{readelf} -d #{dest} 2>/dev/null`
  puts needed.lines.grep(/NEEDED/).join
  bad = needed.lines.grep(/NEEDED/).grep(/libxml2|libxslt|libexslt|libz\.|libiconv/)
  abort "expected static xml/xslt/z, still dynamic: #{bad}" if bad.any?
  syms = `#{readelf} --dyn-syms #{dest} 2>/dev/null`
  abort "missing Init_nokogiri" unless syms.include?("Init_nokogiri")
  leaked = syms.lines.grep(/\bGLOBAL\b/).grep(/\b(?:xmlParseChunk|xsltParseStylesheetDoc|iconv_open)\b/)
  abort "static lib symbols exported" unless leaked.empty?
  loads = `#{readelf} -l #{dest} 2>/dev/null`
  narrow = loads.lines.grep(/^\s*LOAD\b/).select { |l| l.split.last.to_i(16) < 0x4000 }
  abort "LOAD align < 16KB" unless narrow.empty?
end
puts "OK #{dest} size=#{File.size(dest)}"
