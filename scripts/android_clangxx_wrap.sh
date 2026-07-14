#!/usr/bin/env bash
set -euo pipefail
REAL_CXX="${NOKOGIRI_ANDROID_REAL_CXX:?NOKOGIRI_ANDROID_REAL_CXX not set}"
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
exec "$REAL_CXX" "$@"
