#!/usr/bin/env bash
# Bootstrap runners without replacing application sources or dependency locks.
set -euo pipefail
cd "$(dirname "$0")/.."
platforms=("$@")
if (( ${#platforms[@]} == 0 )); then
  platforms=(android windows linux web)
fi
for platform in "${platforms[@]}"; do
  case "$platform" in
    android|windows|linux|web) ;;
    *) echo "Unsupported platform: $platform" >&2; exit 1 ;;
  esac
  if [[ -e "$platform" ]]; then
    echo "Runner already exists: $platform (refusing to overwrite it)" >&2
    exit 1
  fi
done
runner_dir=$(mktemp -d)
trap 'rm -rf "$runner_dir"' EXIT
platform_list=$(IFS=,; echo "${platforms[*]}")
flutter create --no-pub --project-name friend_pager --platforms="$platform_list" "$runner_dir"
for platform in "${platforms[@]}"; do
  cp -R "$runner_dir/$platform" .
  if [[ "$platform" == web ]]; then
    cp tool/flutter_bootstrap.js web/flutter_bootstrap.js
  fi
  if [[ "$platform" == android ]]; then
    # Local HTTP API access in debug builds only. Release has no cleartext exception.
    python3 - <<'PYTHON'
from pathlib import Path
p = Path('android/app/src/debug/AndroidManifest.xml')
s = p.read_text().replace('</manifest>', '    <application android:usesCleartextTraffic="true" />\n</manifest>')
p.write_text(s)
PYTHON
  fi
done
