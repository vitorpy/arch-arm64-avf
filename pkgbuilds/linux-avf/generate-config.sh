#!/usr/bin/env bash
# Generate kernel config for linux-avf
# This script fetches the latest Arch Linux ARM kernel config and applies AVF-specific options

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Fetching Arch Linux ARM kernel config..."
curl -L "https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/master/core/linux-aarch64/config" -o "$SCRIPT_DIR/config.base"

echo "==> Creating final config with AVF options..."
cat "$SCRIPT_DIR/config.base" > "$SCRIPT_DIR/config"

echo "" >> "$SCRIPT_DIR/config"
echo "# AVF-specific options" >> "$SCRIPT_DIR/config"
cat "$SCRIPT_DIR/config.fragment" >> "$SCRIPT_DIR/config"

echo "==> Config generated at $SCRIPT_DIR/config"
echo "==> You may want to run 'make olddefconfig' to resolve any conflicts"
