#!/usr/bin/env bash
set -euo pipefail
dest="$RUNNER_TEMP/friend-pager-supabase"
mkdir -p "$dest"
curl --fail --location --retry 3 https://github.com/supabase/cli/releases/download/v2.122.0/supabase_2.122.0_linux_amd64.tar.gz -o "$dest/cli.tar.gz"
echo '59ed066847b98d7461c60e9109d40cab6b9756177ce06ebb05b51338519f5136  '"$dest/cli.tar.gz" | sha256sum --check
tar -xzf "$dest/cli.tar.gz" -C "$dest"
echo "$dest" >> "$GITHUB_PATH"
