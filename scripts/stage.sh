#!/usr/bin/env bash
# Stage Android MRI 3.3.4 (headers + libruby) from JekyllEx bootstrap.
# Usage: source scripts/stage.sh <aarch64|arm|i686|x86_64>
set -euo pipefail

ARCH="${1:?arch}"
case "$ARCH" in x86) ARCH=i686 ;; esac
case "$ARCH" in aarch64|arm|i686|x86_64) ;; *) echo "bad arch: $ARCH" >&2; exit 1 ;; esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="${NOKOGIRI_ANDROID_STAGE:-$ROOT/stage/$ARCH}"
API="${ANDROID_API:-24}"
# JekyllEx bootstrap (Ruby 3.3.4). Override JEKYLLEX_RUBY_URL_BASE / RUBY_ZIP.
BOOT_VER="${JEKYLLEX_BOOTSTRAP_VERSION:-v0.1.4}"
BOOT_BASE="${JEKYLLEX_RUBY_URL_BASE:-https://github.com/jekyllex/ruby-android/releases/download/${BOOT_VER}}"

: "${NDK:=${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}}"
if [[ -z "${NDK}" || ! -d "${NDK}" ]]; then
  shopt -s nullglob
  for d in "$HOME/Library/Android/sdk/ndk/"* "$HOME/Android/Sdk/ndk/"*; do
    [[ -d "$d/toolchains/llvm/prebuilt" ]] && NDK=$d && break
  done
  shopt -u nullglob
fi
[[ -n "${NDK:-}" && -d "$NDK" ]] || { echo "set NDK" >&2; exit 1; }

HOST=
for t in linux-x86_64 darwin-x86_64 darwin-arm64; do
  [[ -d "$NDK/toolchains/llvm/prebuilt/$t" ]] && HOST=$t && break
done
[[ -n "$HOST" ]] || { echo "no NDK prebuilt" >&2; exit 1; }

case "$ARCH" in
  aarch64) TARGET=aarch64-linux-android;    PLAT=aarch64-linux-android; ZIP_ARCH=aarch64 ;;
  arm)     TARGET=armv7a-linux-androideabi; PLAT=arm-linux-androideabi; ZIP_ARCH=arm ;;
  i686)    TARGET=i686-linux-android;       PLAT=i686-linux-android;    ZIP_ARCH=i686 ;;
  x86_64)  TARGET=x86_64-linux-android;     PLAT=x86_64-linux-android;  ZIP_ARCH=x86_64 ;;
esac

TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/$HOST"
export NDK ARCH TARGET API GEM_PLATFORM="$PLAT" STAGE_DIR="$STAGE" TOOLCHAIN HOST_TAG="$HOST"
export NOKOGIRI_ANDROID_ROOT="$ROOT" NOKOGIRI_ANDROID_ARCH="$ARCH"
export NOKOGIRI_ANDROID_REAL_CC="$TOOLCHAIN/bin/${TARGET}${API}-clang"
export NOKOGIRI_ANDROID_REAL_CXX="$TOOLCHAIN/bin/${TARGET}${API}-clang++"
export AR="$TOOLCHAIN/bin/llvm-ar" RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"
export CC="$ROOT/scripts/ccwrap" CXX="$ROOT/scripts/c++wrap"
export LD="$NOKOGIRI_ANDROID_REAL_CC"
unset NOKOGIRI_USE_SYSTEM_LIBRARIES || true

mkdir -p "$STAGE"
# shellcheck disable=SC1091
source "$ROOT/scripts/toolchain.sh"

fetch_ruby() {
  local zip="${RUBY_ZIP:-ruby-${ZIP_ARCH}.zip}"
  local url="${RUBY_URL:-$BOOT_BASE/$zip}"
  local zpath="$STAGE/$zip"
  [[ -f "$zpath" ]] || curl -fsSL -L -o "$zpath" "$url"
  local x="$STAGE/.x"
  rm -rf "$x" && mkdir -p "$x"
  unzip -qo "$zpath" -d "$x"
  # MRI only — do not stage bootstrap shared libs (would beat static iconv/xml)
  mkdir -p "$STAGE/include" "$STAGE/lib"
  [[ -d "$x/include" ]] && cp -a "$x"/include/ruby-* "$STAGE/include/" 2>/dev/null || true
  # libruby + rbconfig tree
  for f in "$x"/lib/libruby.so*; do
    [[ -e "$f" ]] && cp -a "$f" "$STAGE/lib/"
  done
  if [[ -d "$x/lib/ruby" ]]; then
    mkdir -p "$STAGE/lib/ruby"
    cp -a "$x"/lib/ruby/. "$STAGE/lib/ruby/"
  fi
  rm -rf "$x"
  if [[ -d "$STAGE/lib" ]]; then
    local base
    base=$(basename "$(ls -1 "$STAGE"/lib/libruby.so.*.*.* 2>/dev/null | head -1)")
    if [[ -n "$base" && -e "$STAGE/lib/$base" ]]; then
      ln -sfn "$base" "$STAGE/lib/libruby.so"
      if [[ "$base" =~ ^libruby\.so\.([0-9]+\.[0-9]+)\. ]]; then
        ln -sfn "$base" "$STAGE/lib/libruby.so.${BASH_REMATCH[1]}"
      fi
    fi
  fi
}

if [[ "${SKIP_DEPS:-0}" != 1 ]]; then
  fetch_ruby
fi

if [[ -d "$ROOT/nokogiri/.git" || -f "$ROOT/nokogiri/.git" ]]; then
  VER=$(ruby -e 'print File.read("'"$ROOT"'/nokogiri/lib/nokogiri/version/constant.rb")[/VERSION = "([^"]+)"/,1]' 2>/dev/null || true)
  if [[ -n "${VER:-}" && -d "$ROOT/patches/$VER" ]]; then
    (cd "$ROOT/nokogiri" && git checkout -- ext/nokogiri/extconf.rb 2>/dev/null || true)
    for p in "$ROOT/patches/$VER"/*.patch; do
      [[ -f "$p" ]] || continue
      (cd "$ROOT/nokogiri" && git apply "$p") || true
    done
  fi
fi

RUBY_HDR=$(find "$STAGE/include" -maxdepth 1 -type d -name 'ruby-*' | head -1)
RUBY_API=$(basename "${RUBY_HDR:-ruby-3.3.0}" | sed 's/^ruby-//')
RUBY_MINOR=${RUBY_API%.*}
RUBY_HDR="${RUBY_HDR:-$STAGE/include/ruby-$RUBY_API}"
RUBY_ARCH_HDR="$RUBY_HDR/$PLAT"
if [[ ! -d "$RUBY_ARCH_HDR" ]]; then
  RUBY_ARCH_HDR=$(find "$RUBY_HDR" -maxdepth 1 -type d -name '*-linux-android*' | head -1)
fi
export RUBY_API RUBY_MINOR RUBY_HDR RUBY_ARCH_HDR
export CPPFLAGS="-I$RUBY_HDR -I$RUBY_ARCH_HDR -fPIC"
export CFLAGS="-fPIC -O2"
export LDFLAGS="-L$STAGE/lib -Wl,--as-needed"
export PKG_CONFIG_PATH=""
echo "Android MRI headers: $RUBY_HDR (minor=$RUBY_MINOR)"
