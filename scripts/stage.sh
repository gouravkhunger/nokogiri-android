#!/usr/bin/env bash
# Stage Android MRI only (headers + libruby). Deps are built/static-linked by compile.
# Usage: source scripts/stage.sh <aarch64|arm|i686|x86_64>
set -euo pipefail

ARCH="${1:?arch}"
case "$ARCH" in x86) ARCH=i686 ;; esac
case "$ARCH" in aarch64|arm|i686|x86_64) ;; *) echo "bad arch: $ARCH" >&2; exit 1 ;; esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="${NOKOGIRI_ANDROID_STAGE:-$ROOT/stage/$ARCH}"
API="${ANDROID_API:-24}"
POOL="${TERMUX_POOL:-https://packages-cf.termux.dev/apt/termux-main/pool/main}"

: "${NDK:=${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}}"
if [[ -z "${NDK}" || ! -d "${NDK}" ]]; then
  for d in "$HOME/Library/Android/sdk/ndk/"* "$HOME/Android/Sdk/ndk/"*; do
    [[ -d "$d/toolchains/llvm/prebuilt" ]] && NDK=$d && break
  done
fi
[[ -n "${NDK:-}" && -d "$NDK" ]] || { echo "set NDK" >&2; exit 1; }

HOST=
for t in linux-x86_64 darwin-x86_64 darwin-arm64; do
  [[ -d "$NDK/toolchains/llvm/prebuilt/$t" ]] && HOST=$t && break
done
[[ -n "$HOST" ]] || { echo "no NDK prebuilt" >&2; exit 1; }

case "$ARCH" in
  aarch64) TARGET=aarch64-linux-android;    PLAT=aarch64-linux-android ;;
  arm)     TARGET=armv7a-linux-androideabi; PLAT=arm-linux-androideabi ;;
  i686)    TARGET=i686-linux-android;       PLAT=i686-linux-android ;;
  x86_64)  TARGET=x86_64-linux-android;     PLAT=x86_64-linux-android ;;
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
  local deb="${RUBY_DEB:-ruby_3.4.1-2_${ARCH}.deb}"
  local url="$POOL/r/ruby/$deb"
  [[ -f "$STAGE/$deb" ]] || curl -fsSL -o "$STAGE/$deb" "$url"
  local x="$STAGE/.x"
  rm -rf "$x" && mkdir -p "$x"
  dpkg-deb -x "$STAGE/$deb" "$x"
  local usr
  usr=$(find "$x" -type d -path '*/files/usr' | head -1)
  [[ -n "$usr" ]] || { echo "no usr in ruby deb" >&2; return 1; }
  for s in include lib; do
    [[ -d "$usr/$s" ]] && mkdir -p "$STAGE/$s" && cp -a "$usr/$s"/. "$STAGE/$s"/
  done
  rm -rf "$x"
}

if [[ "${SKIP_DEPS:-0}" != 1 ]]; then
  fetch_ruby
fi

# patches/<version>/*.patch on submodule (idempotent-ish)
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
RUBY_API=$(basename "${RUBY_HDR:-ruby-3.4.0}" | sed 's/^ruby-//')
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
