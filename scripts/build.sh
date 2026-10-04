#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="${1:?usage: $0 <aarch64|arm|i686|x86_64>}"
for d in /opt/homebrew/opt/ruby@3.3/bin /usr/local/opt/ruby@3.3/bin /opt/homebrew/opt/ruby@3.4/bin; do
  [[ -d "$d" ]] && export PATH="$d:/opt/homebrew/bin:$PATH" && break
done
# shellcheck disable=SC1091
source "$ROOT/scripts/stage.sh" "$ARCH"
ruby -e 'require "mini_portile2"' 2>/dev/null || gem install mini_portile2 --no-document
ruby "$ROOT/scripts/compile.rb"
ruby "$ROOT/scripts/package.rb"
shopt -s nullglob
if [[ -n "${GEM_NAME:-}" ]]; then
  gems=( "$ROOT"/pkg/"${GEM_NAME}"-*-"${GEM_PLATFORM}".gem )
else
  gems=( "$ROOT"/pkg/*-"${GEM_PLATFORM}".gem )
fi
[[ ${#gems[@]} -gt 0 ]] || { echo "no gem" >&2; exit 1; }
for gem in "${gems[@]}"; do
  base=$(basename "$gem")
  if [[ "$base" == nokogiri-android-* ]]; then
    GEM_NAME=nokogiri-android ruby "$ROOT/scripts/verify.rb" "$gem"
  else
    GEM_NAME=nokogiri ruby "$ROOT/scripts/verify.rb" "$gem"
  fi
done
ls -la "$ROOT/out/$GEM_PLATFORM" "$ROOT/pkg"
