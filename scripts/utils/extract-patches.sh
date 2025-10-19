#!/usr/bin/env bash
# Extract patches from AVF sources submodule

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "==> Extracting patches from AVF sources..."

# Ensure submodule is initialized
if [ ! -d "$PROJECT_ROOT/avf-sources/.git" ]; then
    echo "Error: AVF sources submodule not initialized"
    echo "Run: git submodule update --init --recursive"
    exit 1
fi

# Extract kernel patch
echo "  -> Copying arm64-balloon.patch"
cp "$PROJECT_ROOT/avf-sources/build/debian/kernel/patches/avf/arm64-balloon.patch" \
   "$PROJECT_ROOT/patches/kernel/"

# Extract ttyd patches
echo "  -> Copying ttyd patches"
cp "$PROJECT_ROOT/avf-sources/build/debian/ttyd/client_cert.patch" \
   "$PROJECT_ROOT/patches/ttyd/"
cp "$PROJECT_ROOT/avf-sources/build/debian/ttyd/xtermjs_a11y.patch" \
   "$PROJECT_ROOT/patches/ttyd/"

# guest-tcpstates.patch is from nixos-avf, should already be in place

echo "==> Patches extracted successfully!"
echo ""
echo "Patches are now available in patches/"
ls -lh "$PROJECT_ROOT/patches"/*/*.patch
