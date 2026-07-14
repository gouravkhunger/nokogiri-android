#!/usr/bin/env bash
# Stage Android (Termux) headers/libs and export NDK cross-compile env for Nokogiri.
# Usage: source setup.sh <arch>   OR   eval "$(./setup.sh <arch> --export)"
# Allowed arch: aarch64, arm, i686, x86_64  (x86 is alias for i686)
set -euo pipefail

EXPORT_ONLY=0
ARCH=""
for arg in "$@"; do
  case "$arg" in
    --export) EXPORT_ONLY=1 ;;
    -*) echo "Unknown option: $arg" >&2; exit 1 ;;
    *) ARCH="$arg" ;;
  esac
done

if [[ -z "${ARCH}" ]]; then
  echo "Usage: $0 <arch> [--export]" >&2
  echo "Allowed: aarch64, arm, i686, x86_64 (x86 -> i686)" >&2
  exit 1
fi

# Normalize aliases
case "$ARCH" in
  x86) ARCH=i686 ;;
esac

case "$ARCH" in
  aarch64|arm|i686|x86_64) echo "Architecture accepted: $ARCH" ;;
  *)
    echo "Error: Unsupported architecture '$ARCH'" >&2
    echo "Allowed: aarch64, arm, i686, x86_64" >&2
    exit 1
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGE_DIR="${NOKOGIRI_ANDROID_STAGE:-$ROOT_DIR/stage/$ARCH}"
mkdir -p "$STAGE_DIR"/{bin,include,lib}

# Resolve NDK
if [[ -z "${NDK:-}" ]]; then
  if [[ -n "${ANDROID_NDK_HOME:-}" ]]; then
    NDK="$ANDROID_NDK_HOME"
  elif [[ -n "${ANDROID_NDK_ROOT:-}" ]]; then
    NDK="$ANDROID_NDK_ROOT"
  else
    for cand in \
      "$HOME/Library/Android/sdk/ndk/"* \
      "$HOME/Android/Sdk/ndk/"* \
      /opt/android-ndk* \
      /usr/local/lib/android/ndk/*; do
      if [[ -d "$cand/toolchains/llvm/prebuilt" ]]; then
        NDK="$cand"
        break
      fi
    done
  fi
fi

if [[ -z "${NDK:-}" || ! -d "$NDK" ]]; then
  echo "Error: Android NDK not found. Set NDK or ANDROID_NDK_HOME." >&2
  exit 1
fi
export NDK

# Host prebuilt triple (linux-x86_64, darwin-x86_64, darwin-arm64)
HOST_TAG=""
for tag in linux-x86_64 darwin-x86_64 darwin-arm64; do
  if [[ -d "$NDK/toolchains/llvm/prebuilt/$tag" ]]; then
    HOST_TAG="$tag"
    break
  fi
done
if [[ -z "$HOST_TAG" ]]; then
  echo "Error: No NDK llvm prebuilt found under $NDK/toolchains/llvm/prebuilt" >&2
  ls -la "$NDK/toolchains/llvm/prebuilt" 2>/dev/null || true
  exit 1
fi

API="${ANDROID_API:-24}"

case "$ARCH" in
  aarch64) TARGET="aarch64-linux-android"; GEM_PLATFORM="aarch64-linux-android" ;;
  arm)     TARGET="armv7a-linux-androideabi"; GEM_PLATFORM="arm-linux-androideabi" ;;
  i686)    TARGET="i686-linux-android"; GEM_PLATFORM="i686-linux-android" ;;
  x86_64)  TARGET="x86_64-linux-android"; GEM_PLATFORM="x86_64-linux-android" ;;
esac

# Package versions (override via env)
ZLIB_DEB="${ZLIB_DEB:-zlib_1.3.2_${ARCH}.deb}"
RUBY_DEB="${RUBY_DEB:-ruby_3.4.1-2_${ARCH}.deb}"
ICONV_DEB="${ICONV_DEB:-libiconv_1.18-1_${ARCH}.deb}"
XML2_DEB="${XML2_DEB:-libxml2_2.15.3-2_${ARCH}.deb}"
XSLT_DEB="${XSLT_DEB:-libxslt_1.1.45-1_${ARCH}.deb}"
# Also pull android-support if available (Termux link helper)
SUPPORT_DEB="${SUPPORT_DEB:-libandroid-support_29-${ARCH}.deb}"

TERMUX_POOL="${TERMUX_POOL:-https://packages-cf.termux.dev/apt/termux-main/pool/main}"

download_and_merge() {
  local url="$1"
  local deb_name
  deb_name="$(basename "$url")"
  local deb_path="$STAGE_DIR/$deb_name"

  if [[ ! -f "$deb_path" ]]; then
    echo "Downloading $deb_name ..."
    if ! curl -fsSL -o "$deb_path" "$url"; then
      echo "Warning: failed to download $url (optional?)" >&2
      rm -f "$deb_path"
      return 1
    fi
  else
    echo "Using cached $deb_name"
  fi

  local extract="$STAGE_DIR/.extract"
  rm -rf "$extract"
  mkdir -p "$extract"
  dpkg-deb -x "$deb_path" "$extract"

  # Termux layout: data/data/com.termux/files/usr/*
  local usr=""
  if [[ -d "$extract/data/data/com.termux/files/usr" ]]; then
    usr="$extract/data/data/com.termux/files/usr"
  elif [[ -d "$extract/data/data/xyz.jekyllex/files/usr" ]]; then
    usr="$extract/data/data/xyz.jekyllex/files/usr"
  else
    usr="$(find "$extract" -type d -path '*/files/usr' | head -1 || true)"
  fi

  if [[ -z "$usr" || ! -d "$usr" ]]; then
    echo "Warning: could not find usr/ in $deb_name" >&2
    return 1
  fi

  for sub in bin include lib share; do
    if [[ -d "$usr/$sub" ]]; then
      mkdir -p "$STAGE_DIR/$sub"
      cp -a "$usr/$sub"/. "$STAGE_DIR/$sub"/
    fi
  done
  rm -rf "$extract"
  return 0
}

if [[ "${SKIP_DEPS:-0}" != "1" ]]; then
  download_and_merge "$TERMUX_POOL/z/zlib/$ZLIB_DEB" || true
  download_and_merge "$TERMUX_POOL/r/ruby/$RUBY_DEB" || { echo "ERROR: ruby deb required" >&2; exit 1; }
  download_and_merge "$TERMUX_POOL/libi/libiconv/$ICONV_DEB" || true
  download_and_merge "$TERMUX_POOL/libx/libxml2/$XML2_DEB" || { echo "ERROR: libxml2 deb required" >&2; exit 1; }
  download_and_merge "$TERMUX_POOL/libx/libxslt/$XSLT_DEB" || { echo "ERROR: libxslt deb required" >&2; exit 1; }
  # optional android-support (package path may vary)
  download_and_merge "$TERMUX_POOL/liba/libandroid-support/$SUPPORT_DEB" || \
    download_and_merge "$TERMUX_POOL/a/android-support/android-support_28-3_${ARCH}.deb" || true
fi

# Detect Ruby API version from staged headers
RUBY_API=""
if [[ -d "$STAGE_DIR/include" ]]; then
  RUBY_API="$(find "$STAGE_DIR/include" -maxdepth 1 -type d -name 'ruby-*' | head -1 | xargs -I{} basename {} | sed 's/^ruby-//')"
fi
RUBY_API="${RUBY_API:-3.4.0}"
RUBY_MINOR="$(echo "$RUBY_API" | cut -d. -f1-2)"

TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/$HOST_TAG"
CLANG="$TOOLCHAIN/bin/${TARGET}${API}-clang"
CLANGXX="$TOOLCHAIN/bin/${TARGET}${API}-clang++"

if [[ ! -x "$CLANG" ]]; then
  echo "Error: clang not found at $CLANG" >&2
  exit 1
fi

# Prefer arch-specific ruby headers
RUBY_HDR="$STAGE_DIR/include/ruby-$RUBY_API"
RUBY_ARCH_HDR="$RUBY_HDR/$GEM_PLATFORM"
# arm target may use armv7a-linux-androideabi or arm-linux-androideabi in headers
if [[ ! -d "$RUBY_ARCH_HDR" ]]; then
  for cand in "$RUBY_HDR"/*-linux-android*; do
    if [[ -d "$cand" ]]; then
      RUBY_ARCH_HDR="$cand"
      break
    fi
  done
fi

export NDK
export ARCH
export TARGET
export API
export GEM_PLATFORM
export STAGE_DIR
export TOOLCHAIN
export HOST_TAG
export RUBY_API
export RUBY_MINOR
export RUBY_HDR
export RUBY_ARCH_HDR

export LD="$TOOLCHAIN/bin/ld.lld"
export AR="$TOOLCHAIN/bin/llvm-ar"
export SYSROOT="$TOOLCHAIN/sysroot"
export STRIP="$TOOLCHAIN/bin/llvm-strip"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export CC="$CLANG"
export CXX="$CLANGXX"
export AS="$CC"

export NOKOGIRI_USE_SYSTEM_LIBRARIES=1
# No absolute rpath into stage dir — device resolves via LD_LIBRARY_PATH / usr/lib
export LDFLAGS="-L${STAGE_DIR}/lib -Wl,--as-needed"
export CPPFLAGS="-I${STAGE_DIR}/include -I${RUBY_HDR} -I${RUBY_ARCH_HDR} -I${STAGE_DIR}/include/libxml2"
export CFLAGS="-fPIC -O2 -fno-strict-aliasing"
export PKG_CONFIG_PATH="${STAGE_DIR}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export PKG_CONFIG_LIBDIR="${STAGE_DIR}/lib/pkgconfig"
# Avoid host pkg-config pollution
export PKG_CONFIG_SYSROOT_DIR=""

# Path helpers for build scripts
export NOKOGIRI_ANDROID_ROOT="$ROOT_DIR"
export NOKOGIRI_ANDROID_ARCH="$ARCH"

echo "NDK=$NDK"
echo "HOST_TAG=$HOST_TAG"
echo "TARGET=$TARGET API=$API"
echo "STAGE_DIR=$STAGE_DIR"
echo "RUBY_API=$RUBY_API RUBY_MINOR=$RUBY_MINOR"
echo "GEM_PLATFORM=$GEM_PLATFORM"
echo "CC=$CC"

if [[ "$EXPORT_ONLY" -eq 1 ]]; then
  # Print exports for eval
  cat <<EOF
export NDK=$(printf %q "$NDK")
export ARCH=$(printf %q "$ARCH")
export TARGET=$(printf %q "$TARGET")
export API=$(printf %q "$API")
export GEM_PLATFORM=$(printf %q "$GEM_PLATFORM")
export STAGE_DIR=$(printf %q "$STAGE_DIR")
export TOOLCHAIN=$(printf %q "$TOOLCHAIN")
export HOST_TAG=$(printf %q "$HOST_TAG")
export RUBY_API=$(printf %q "$RUBY_API")
export RUBY_MINOR=$(printf %q "$RUBY_MINOR")
export RUBY_HDR=$(printf %q "$RUBY_HDR")
export RUBY_ARCH_HDR=$(printf %q "$RUBY_ARCH_HDR")
export LD=$(printf %q "$LD")
export AR=$(printf %q "$AR")
export SYSROOT=$(printf %q "$SYSROOT")
export STRIP=$(printf %q "$STRIP")
export RANLIB=$(printf %q "$RANLIB")
export CC=$(printf %q "$CC")
export CXX=$(printf %q "$CXX")
export AS=$(printf %q "$AS")
export NOKOGIRI_USE_SYSTEM_LIBRARIES=1
export LDFLAGS=$(printf %q "$LDFLAGS")
export CPPFLAGS=$(printf %q "$CPPFLAGS")
export CFLAGS=$(printf %q "$CFLAGS")
export PKG_CONFIG_PATH=$(printf %q "$PKG_CONFIG_PATH")
export NOKOGIRI_ANDROID_ROOT=$(printf %q "$ROOT_DIR")
export NOKOGIRI_ANDROID_ARCH=$(printf %q "$ARCH")
EOF
fi
