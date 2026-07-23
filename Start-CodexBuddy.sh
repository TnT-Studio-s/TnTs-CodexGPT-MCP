#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
resource_dir="$script_dir/linux"
if [[ ! -f "$resource_dir/codex_buddy.py" ]]; then
    resource_dir="$script_dir"
fi

exec python3 "$resource_dir/codex_buddy.py" "$@"
