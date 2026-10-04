# frozen_string_literal: true

require "rbconfig"

def noko(key)
  ENV.fetch(key) { abort "missing #{key}" }
end

rbc = noko("NOKO_RBC")
stage = noko("NOKO_STAGE")
host_triple = noko("NOKO_TARGET")
cc = noko("NOKO_CC")
cxx = noko("NOKO_CXX")
real_cc = noko("NOKO_REAL_CC")
ar = noko("NOKO_AR")
ranlib = noko("NOKO_RANLIB")
strip = noko("NOKO_STRIP")
ruby_hdr = noko("NOKO_RUBY_HDR")
ruby_arch_hdr = noko("NOKO_RUBY_ARCH_HDR")
host_ruby = noko("NOKO_HOST_RUBY")

_rbc = File.read(rbc)
_rbc = _rbc.lines.reject { |l|
  l.include?("RUBY_VERSION.start_with?") || l.include?("doesn't match executable version")
}.join
eval(_rbc, binding, rbc)

re = %r{/data/data/[^/]+/files/usr}
%w[CONFIG MAKEFILE_CONFIG].each do |c|
  RbConfig.const_get(c).each { |k, v| RbConfig.const_get(c)[k] = v.gsub(re, stage) if v.is_a?(String) }
end

{
  "CC" => cc, "CXX" => cxx, "LD" => real_cc,
  "AR" => ar, "RANLIB" => ranlib, "STRIP" => strip,
  "CPP" => "#{cc} -E", "NULLCMD" => ":",
  "host" => host_triple, "host_alias" => host_triple,
  "target" => host_triple, "target_alias" => host_triple,
  "build" => RbConfig::CONFIG["host"],
  "build_alias" => "",
}.each { |k, v| RbConfig::CONFIG[k] = RbConfig::MAKEFILE_CONFIG[k] = v }

RbConfig::CONFIG["rubyhdrdir"] = RbConfig::MAKEFILE_CONFIG["rubyhdrdir"] = ruby_hdr
RbConfig::CONFIG["rubyarchhdrdir"] = RbConfig::MAKEFILE_CONFIG["rubyarchhdrdir"] = ruby_arch_hdr
RbConfig::CONFIG["libdir"] = RbConfig::MAKEFILE_CONFIG["libdir"] = File.join(stage, "lib")
arch = File.basename(File.dirname(rbc))
RbConfig::CONFIG["arch"] = RbConfig::MAKEFILE_CONFIG["arch"] = arch
RbConfig::CONFIG["sitearch"] = RbConfig::MAKEFILE_CONFIG["sitearch"] = arch
RbConfig::CONFIG["target_os"] = RbConfig::MAKEFILE_CONFIG["target_os"] = "linux-android"
RbConfig::CONFIG["host_os"] = RbConfig::MAKEFILE_CONFIG["host_os"] = "linux-android"
RbConfig::CONFIG["target_cpu"] = RbConfig::MAKEFILE_CONFIG["target_cpu"] = host_triple.split("-").first.sub("armv7a", "arm")
RbConfig::CONFIG["DLEXT"] = RbConfig::MAKEFILE_CONFIG["DLEXT"] = "so"
RbConfig::CONFIG["bindir"] = RbConfig::MAKEFILE_CONFIG["bindir"] = File.dirname(host_ruby)

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
  RbConfig::CONFIG[k] = RbConfig::MAKEFILE_CONFIG[k] = "-L#{libdir} #{RbConfig::CONFIG[k]}".strip
end

extra = %w[-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384 -Wl,--exclude-libs,ALL]
%w[LDFLAGS DLDFLAGS].each do |k|
  cur = RbConfig::CONFIG[k].to_s
  add = extra.reject { |f| cur.include?(f) }
  next if add.empty?
  RbConfig::CONFIG[k] = RbConfig::MAKEFILE_CONFIG[k] = "#{cur} #{add.join(" ")}".strip
end

ENV["CC"] = cc
ENV["CXX"] = cxx
ENV["AR"] = ar
ENV["RANLIB"] = ranlib
ENV["STRIP"] = strip
ENV["LD"] = real_cc
ENV.delete("NOKOGIRI_USE_SYSTEM_LIBRARIES")
ENV["CPPFLAGS"] = noko("NOKO_CPPFLAGS")
ENV["LDFLAGS"] = noko("NOKO_LDFLAGS")
ENV["CFLAGS"] = noko("NOKO_CFLAGS")
ENV["PKG_CONFIG_PATH"] = ""
ENV["PKG_CONFIG_LIBDIR"] = ""
