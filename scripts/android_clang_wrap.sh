#!/usr/bin/env bash
# Host NDK clang must NOT see Android stage libs on LD_LIBRARY_PATH.
# On x86_64 (same arch as typical CI hosts), Android .so files get loaded
# into the host clang process and break it (invalid ELF header on libc).
# -L flags still find libraries at link time; LD_LIBRARY_PATH is only needed
# for running the binary, which we cannot do for Android targets on the host.
set -euo pipefail
REAL_CC="${NOKOGIRI_ANDROID_REAL_CC:?NOKOGIRI_ANDROID_REAL_CC not set}"
# Drop any path that looks like our stage tree; keep empty/other host paths if any
if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
  NEW_LDPATH=""
  IFS=':' read -ra PARTS <<< "$LD_LIBRARY_PATH"
  for p in "${PARTS[@]}"; do
    [[ -z "$p" ]] && continue
    if [[ "$p" == *"/stage/"* ]] || [[ "$p" == "." ]]; then
      continue
    fi
    NEW_LDPATH="${NEW_LDPATH:+$NEW_LDPATH:}$p"
  done
  export LD_LIBRARY_PATH="$NEW_LDPATH"
else
  unset LD_LIBRARY_PATH || true
fi
# Also clear LIBRARY_PATH pollution if present
if [[ -n "${LIBRARY_PATH:-}" ]]; then
  NEW_LP=""
  IFS=':' read -ra PARTS <<< "$LIBRARY_PATH"
  for p in "${PARTS[@]}"; do
    [[ -z "$p" ]] && continue
    if [[ "$p" == *"/stage/"* ]]; then
      continue
    fi
    NEW_LP="${NEW_LP:+$NEW_LP:}$p"
  done
  export LIBRARY_PATH="$NEW_LP"
fi
exec "$REAL_CC" "$@"
