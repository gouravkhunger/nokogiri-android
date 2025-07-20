#!/bin/bash

# Validate the input
if [ $# -ne 1 ]; then
    echo "Usage: $0 <arch>"
    echo "Allowed values: aarch64, arm, x86, i686, x86_64"
    exit 1
fi

ARCH="$1"

case "$ARCH" in
    aarch64|arm|x86|i686|x86_64)
        echo "Architecture accepted: $ARCH"
        ;;
    *)
        echo "Error: Unsupported architecture '$ARCH'"
        echo "Allowed: aarch64, arm, x86, i686, x86_64"
        exit 1
        ;;
esac

# Set up files
mkdir -p tmp && cd tmp
mkdir -p bin include lib

curl -L -O https://packages-cf.termux.dev/apt/termux-main/pool/main/z/zlib/zlib_1.3.1_${ARCH}.deb
curl -L -O https://packages-cf.termux.dev/apt/termux-main/pool/main/r/ruby/ruby_3.4.1-1_${ARCH}.deb
curl -L -O https://packages-cf.termux.dev/apt/termux-main/pool/main/libi/libiconv/libiconv_1.18_${ARCH}.deb
curl -L -O https://packages-cf.termux.dev/apt/termux-main/pool/main/libx/libxml2/libxml2_2.14.5_${ARCH}.deb
curl -L -O https://packages-cf.termux.dev/apt/termux-main/pool/main/libx/libxslt/libxslt_1.1.43-1_${ARCH}.deb

for deb in ./*.deb; do
    mkdir -p tmp
    dpkg-deb -x "$deb" .
    mv data/data/com.termux/files/usr/* tmp

    # Merge bin
    if [ -d tmp/bin ]; then
        cp -a tmp/bin/. bin/
    fi

    # Merge include
    if [ -d tmp/include ]; then
        cp -a tmp/include/. include/
    fi

    # Merge lib
    if [ -d tmp/lib ]; then
        cp -a tmp/lib/. lib/
    fi

    # Clean up for next package
    rm -rf tmp data
done

rm -rf *.deb

# Set up environment
case "$ARCH" in
  aarch64)
    export TARGET="aarch64-linux-android"
    ;;
  arm)
    export TARGET="armv7a-linux-androideabi"
    ;;
  i686)
    export TARGET="i686-linux-android"
    ;;
  x86_64)
    export TARGET="x86_64-linux-android"
    ;;
esac

export API=24
export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/darwin-x86_64
export LD=$TOOLCHAIN/bin/ld
export AR=$TOOLCHAIN/bin/llvm-ar
export SYSROOT=$TOOLCHAIN/sysroot
export STRIP=$TOOLCHAIN/bin/llvm-strip
export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
export CC=$TOOLCHAIN/bin/$TARGET$API-clang
export CXX=$TOOLCHAIN/bin/$TARGET$API-clang++
export AS=$CC

export NOKOGIRI_USE_SYSTEM_LIBRARIES=1
export LDFLAGS="-L. -L$(pwd)/tmp/lib -Wl,-rpath=$(pwd)/tmp/lib "
export CPPFLAGS="-I$(pwd)/tmp/include -I$(pwd)/tmp/include/ruby-3.4.0 "
