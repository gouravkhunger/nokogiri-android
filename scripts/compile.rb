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
cc = need("CC")
cxx = need("CXX")
ar = need("AR")
real_cc = need("NOKOGIRI_ANDROID_REAL_CC")
ruby_hdr = need("RUBY_HDR")
ruby_arch_hdr = need("RUBY_ARCH_HDR")
host_ruby = RbConfig.ruby
ranlib = ENV.fetch("RANLIB", File.join(File.dirname(ar), "llvm-ranlib"))
strip = ENV.fetch("STRIP", File.join(File.dirname(ar), "llvm-strip"))

src = File.directory?(File.join(root, "nokogiri", "ext", "nokogiri")) ? File.join(root, "nokogiri") : root
ext = File.join(src, "ext", "nokogiri")
abort "no ext" unless File.directory?(ext)

%w[Makefile nokogiri.so mkmf.log].each { |f| FileUtils.rm_f(File.join(ext, f)) }
Dir.glob(File.join(ext, "*.{o,so}")).each { |f| FileUtils.rm_f(f) }
FileUtils.rm_rf([File.join(ext, "tmp"), File.join(ext, "ports")])

rbc = Dir.glob(File.join(stage, "lib", "ruby", api, "*", "rbconfig.rb")).find { |p| p.include?("linux-android") }
abort "no rbconfig" unless rbc

preload = File.join(root, "scripts", ".preload.rb")
File.write(preload, <<~RB)
  require "rbconfig"
  load #{rbc.inspect}
  stage = #{stage.inspect}
  re = %r{/data/data/[^/]+/files/usr}
  %w[CONFIG MAKEFILE_CONFIG].each do |c|
    RbConfig.const_get(c).each { |k, v| RbConfig.const_get(c)[k] = v.gsub(re, stage) if v.is_a?(String) }
  end
  {
    "CC" => #{cc.inspect}, "CXX" => #{cxx.inspect}, "LD" => #{real_cc.inspect},
    "AR" => #{ar.inspect}, "RANLIB" => #{ranlib.inspect}, "STRIP" => #{strip.inspect},
    "CPP" => #{(cc + " -E").inspect}, "NULLCMD" => ":",
  }.each { |k, v| RbConfig::CONFIG[k] = RbConfig::MAKEFILE_CONFIG[k] = v }
  RbConfig::CONFIG["rubyhdrdir"] = RbConfig::MAKEFILE_CONFIG["rubyhdrdir"] = #{ruby_hdr.inspect}
  RbConfig::CONFIG["rubyarchhdrdir"] = RbConfig::MAKEFILE_CONFIG["rubyarchhdrdir"] = #{ruby_arch_hdr.inspect}
  RbConfig::CONFIG["libdir"] = RbConfig::MAKEFILE_CONFIG["libdir"] = File.join(stage, "lib")
  arch = File.basename(File.dirname(#{rbc.inspect}))
  RbConfig::CONFIG["arch"] = RbConfig::MAKEFILE_CONFIG["arch"] = arch
  RbConfig::CONFIG["sitearch"] = RbConfig::MAKEFILE_CONFIG["sitearch"] = arch
  RbConfig::CONFIG["DLEXT"] = RbConfig::MAKEFILE_CONFIG["DLEXT"] = "so"
  RbConfig::CONFIG["bindir"] = RbConfig::MAKEFILE_CONFIG["bindir"] = File.dirname(#{host_ruby.inspect})
  %w[CFLAGS CPPFLAGS LDFLAGS DLDFLAGS].each do |k|
    raw = RbConfig::CONFIG[k].to_s.gsub(/\$\([^)]*\)/, " ")
    cleaned = raw.split.reject { |f|
      f.include?("/data/data/") || f.include?("android-support") ||
        f.start_with?("-isystem") || f.start_with?("-Wl,-rpath") ||
        %w[-rdynamic -Wl,-export-dynamic -Wl,--enable-new-dtags].include?(f)
    }
    RbConfig::CONFIG[k] = RbConfig::MAKEFILE_CONFIG[k] = cleaned.join(" ")
  end
  %w[LIBS LIBRUBYARG LIBRUBYARG_SHARED SOLIBS].each do |k|
    next unless RbConfig::CONFIG[k]
    RbConfig::CONFIG[k] = RbConfig::MAKEFILE_CONFIG[k] =
      RbConfig::CONFIG[k].to_s.split.reject { |f| %w[-lpthread -lrt -ldl -lutil -pthread].include?(f) }.join(" ")
  end
  libdir = File.join(stage, "lib")
  %w[LDFLAGS DLDFLAGS].each do |k|
    RbConfig::CONFIG[k] = RbConfig::MAKEFILE_CONFIG[k] = "-L\#{libdir} \#{RbConfig::CONFIG[k]}".strip
  end
  ENV["CC"] = #{cc.inspect}
  ENV["CXX"] = #{cxx.inspect}
  ENV["AR"] = #{ar.inspect}
  ENV["NOKOGIRI_USE_SYSTEM_LIBRARIES"] = "1"
  ENV["CPPFLAGS"] = #{ENV.fetch("CPPFLAGS", "").inspect}
  ENV["LDFLAGS"] = #{ENV.fetch("LDFLAGS", "").inspect}
  ENV["CFLAGS"] = #{ENV.fetch("CFLAGS", "-fPIC -O2").inspect}
  ENV["PKG_CONFIG_PATH"] = File.join(stage, "lib", "pkgconfig")
RB

begin
  require "mini_portile2"
rescue LoadError
  system(host_ruby, "-S", "gem", "install", "mini_portile2", "--no-document") || abort("mini_portile2")
  Gem.clear_paths
  require "mini_portile2"
end

args = [
  "--use-system-libraries", "--disable-clean", "--disable-static", "--prevent-strip",
  "--with-opt-dir=#{stage}", "--srcdir=#{ext}",
  "--with-xml2-include=#{stage}/include/libxml2", "--with-xml2-lib=#{stage}/lib",
  "--with-xslt-include=#{stage}/include", "--with-xslt-lib=#{stage}/lib",
  "--with-exslt-include=#{stage}/include", "--with-exslt-lib=#{stage}/lib",
  "--with-iconv-include=#{stage}/include", "--with-iconv-lib=#{stage}/lib",
  "--with-zlib-include=#{stage}/include", "--with-zlib-lib=#{stage}/lib",
]

Dir.chdir(ext) do
  abort "extconf" unless system(host_ruby, "-r", preload, "extconf.rb", *args)
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
puts "OK #{dest}"
