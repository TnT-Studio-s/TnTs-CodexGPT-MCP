#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
applications_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
resource_dir="$script_dir"
if [[ ! -f "$resource_dir/codex_buddy.py" ]]; then
    resource_dir="$script_dir/linux"
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "Codex Buddy needs python3. Install it with your distribution package manager." >&2
    exit 1
fi

if ! python3 -c 'import tkinter' >/dev/null 2>&1; then
    echo "Codex Buddy needs Tkinter. Install the GUI package for your distro:" >&2
    echo "  Debian/Ubuntu: sudo apt install python3-tk" >&2
    echo "  Fedora:        sudo dnf install python3-tkinter" >&2
    echo "  Arch:          sudo pacman -S tk" >&2
    exit 1
fi

mkdir -p "$bin_dir" "$applications_dir"
install -m 755 "$resource_dir/codex_buddy.py" "$bin_dir/codex-buddy"
install -m 644 "$resource_dir/codex-buddy.desktop" "$applications_dir/codex-buddy.desktop"

echo "Installed Codex Buddy to $bin_dir/codex-buddy"
echo "If $bin_dir is not on PATH, launch it with: $bin_dir/codex-buddy"
echo "The app reads ~/.codex/sessions and can run alongside the Linux Codex Desktop port."
