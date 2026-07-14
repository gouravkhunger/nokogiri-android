#!/usr/bin/env bash
# Full NDK build + package for one Android ABI.
# Usage: ./scripts/build_android.sh <arch>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
ARCH="${1:?Usage: $0 <aarch64|arm|i686|x86_64>}"

# Prefer modern Ruby on macOS (Homebrew) when available
if [[ -d /opt/homebrew/opt/ruby@3.4/bin ]]; then
  export PATH="/opt/homebrew/opt/ruby@3.4/bin:/opt/homebrew/bin:$PATH"
elif [[ -d /usr/local/opt/ruby@3.4/bin ]]; then
  export PATH="/usr/local/opt/ruby@3.4/bin:/usr/local/bin:$PATH"
fi

echo "Host Ruby: $(command -v ruby) ($(ruby -v))"

# shellcheck disable=SC1091
source "$ROOT/setup.sh" "$ARCH"

# Host helper gems for extconf / packaging
ruby -e 'require "mini_portile2"' 2>/dev/null || gem install mini_portile2 --no-document
ruby -e 'require "rubygems/package"' 

echo "==> Cross-compiling for $GEM_PLATFORM"
ruby "$ROOT/scripts/cross_compile.rb"

echo "==> Packaging gem"
ruby "$ROOT/scripts/package_gem.rb"

echo "==> Verifying gem"
gemfile=$(ls "$ROOT"/pkg/nokogiri-*-"${GEM_PLATFORM}".gem | head -1)
ruby "$ROOT/scripts/verify_gem.rb" "$gemfile"

echo "==> Artifacts"
ls -la "$ROOT/out/$GEM_PLATFORM/" || true
ls -la "$ROOT/pkg/" || true
