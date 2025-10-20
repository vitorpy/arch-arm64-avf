#!/bin/bash
# 50-package-image.sh
# Packages the disk image for AVF (extracts partitions, creates tarball)

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Packaging Image for AVF ===${NC}"

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")}"
BUILD_DIR="${BUILD_DIR:-${PROJECT_ROOT}/build}"
DISK_IMAGE="${BUILD_DIR}/disk.img"

# Verify disk image exists
if [[ ! -f "${DISK_IMAGE}" ]]; then
    echo "ERROR: Disk image not found. Run 40-create-disk-image.sh first"
    exit 1
fi

# Load partition GUIDs
EFI_GUID=$(cat "${BUILD_DIR}/efi_guid")
ROOT_GUID=$(cat "${BUILD_DIR}/root_guid")

echo "Using partition GUIDs:"
echo "  EFI: ${EFI_GUID}"
echo "  Root: ${ROOT_GUID}"

# Set up loop device
echo "Setting up loop device..."
LOOP_DEV=$(sudo losetup --find --show --partscan "${DISK_IMAGE}")
echo "Loop device: ${LOOP_DEV}"

# Get partition information
echo "Reading partition information..."
PART_INFO=$(sudo parted -s "${LOOP_DEV}" unit s print)

# Extract partition start and size (in 512-byte sectors)
EFI_START=$(echo "$PART_INFO" | awk '/^ 1/{print $2}' | sed 's/s//')
EFI_SIZE=$(echo "$PART_INFO" | awk '/^ 1/{print $4}' | sed 's/s//')
ROOT_START=$(echo "$PART_INFO" | awk '/^ 2/{print $2}' | sed 's/s//')
ROOT_SIZE=$(echo "$PART_INFO" | awk '/^ 2/{print $4}' | sed 's/s//')

echo "EFI partition: start=${EFI_START}s, size=${EFI_SIZE}s"
echo "Root partition: start=${ROOT_START}s, size=${ROOT_SIZE}s"

# Extract EFI partition
echo "Extracting EFI partition..."
sudo dd if="${LOOP_DEV}p1" of="${BUILD_DIR}/efi_part" bs=512 status=progress

# Extract root partition
echo "Extracting root partition..."
sudo dd if="${LOOP_DEV}p2" of="${BUILD_DIR}/root_part" bs=512 status=progress

# Cleanup loop device
sudo losetup -d "${LOOP_DEV}"

# Fix filesystem compatibility for Android
echo "Fixing filesystem compatibility..."
# Android's e2fsck doesn't support orphan_file feature
sudo tune2fs -O ^orphan_file "${BUILD_DIR}/root_part"

# Verify EFI partition
echo "Verifying EFI partition..."
sudo fsck.fat -v -a "${BUILD_DIR}/efi_part" || {
    echo -e "${YELLOW}WARNING: EFI partition verification had warnings${NC}"
}

# Create vm_config.json with actual GUIDs
echo "Generating VM configuration..."
sed "s/{EFI_PART_GUID}/${EFI_GUID}/g; s/{ROOT_PART_GUID}/${ROOT_GUID}/g" \
    "${PROJECT_ROOT}/configs/vm_config.json.template" > "${BUILD_DIR}/vm_config.json"

# Create build_id file
echo "Creating build identifier..."
BUILD_ID="archarm-avf-$(date +%Y%m%d-%H%M%S)"
echo "${BUILD_ID}" > "${BUILD_DIR}/build_id"

# Create README for the image
echo "Creating installation README..."
cat > "${BUILD_DIR}/README.md" <<EOF
# Arch Linux ARM for AVF - Installation Instructions

**Build ID**: ${BUILD_ID}
**Build Date**: $(date)

## Installation Steps

### Prerequisites
- Android device with AVF support (Android 15+ or 16+)
- Debuggable build or root access
- ADB installed on computer

### Method 1: Installation on Debuggable Android

1. Copy this tarball to your device:
   \`\`\`bash
   adb push image-*.tar.gz /sdcard/linux/images.tar.gz
   \`\`\`

2. Clear existing VM data:
   \`\`\`bash
   adb shell
   rm -rfv /data/data/com.android.virtualization.terminal/{files/*,vm/*}
   exit
   \`\`\`

3. Launch the Terminal app - it will auto-install the image

### Method 2: Installation with Root

1. Enable debuggable mode temporarily:
   \`\`\`bash
   adb shell su -c "magisk resetprop ro.debuggable 1"
   adb reboot
   \`\`\`

2. Follow Method 1 steps

3. After installation, disable debuggable mode:
   \`\`\`bash
   adb shell su -c "magisk resetprop ro.debuggable 0"
   adb reboot
   \`\`\`

## Default Credentials

- **Username**: droid
- **Password**: (none - passwordless login)
- **Sudo**: Enabled without password for wheel group

## First Boot

On first boot, the system will:
1. Auto-resize the root partition to use available space
2. Start all AVF services
3. Publish ttyd service via mDNS
4. Be discoverable by Terminal app

## Accessing the System

1. Open the Terminal app on your Android device
2. The VM should be auto-discovered and connected
3. You'll be automatically logged in as 'droid'

## Troubleshooting

Check logs with:
\`\`\`bash
adb logcat | grep -i virtualization
\`\`\`

Console output:
\`\`\`bash
adb shell "cat /data/local/tmp/terminal-*.log"
\`\`\`

## Package Management

Update packages:
\`\`\`bash
sudo pacman -Syu
\`\`\`

Install packages:
\`\`\`bash
sudo pacman -S package-name
\`\`\`

## Filesystem Layout

- \`/\` - Root filesystem (auto-resizable ext4)
- \`/boot\` - EFI partition with kernel and bootloader
- \`/mnt/internal\` - AVF internal (certificates, gRPC)
- \`/mnt/shared\` - Android shared storage (/storage/emulated)

## Support

- GitHub: https://github.com/vitorpy/arch-arm64-avf
- Issues: https://github.com/vitorpy/arch-arm64-avf/issues

---
Based on NixOS AVF: https://github.com/nix-community/nixos-avf
EOF

# Create the final tarball
echo "Creating final tarball..."
OUTPUT_TARBALL="${BUILD_DIR}/image-${BUILD_ID}-aarch64.tar.gz"

cd "${BUILD_DIR}"
tar cv build_id efi_part root_part vm_config.json README.md | pigz -9 > "${OUTPUT_TARBALL}"
cd - > /dev/null

# Calculate checksums
echo "Calculating checksums..."
sha256sum "${OUTPUT_TARBALL}" > "${OUTPUT_TARBALL}.sha256"

# Show file information
FILE_SIZE=$(du -h "${OUTPUT_TARBALL}" | cut -f1)

echo ""
echo -e "${GREEN}=== Image Packaged Successfully ===${NC}"
echo "Output: ${OUTPUT_TARBALL}"
echo "Size: ${FILE_SIZE}"
echo "SHA256: $(cat "${OUTPUT_TARBALL}.sha256")"
echo ""
echo "To install on Android device:"
echo "  adb push \"${OUTPUT_TARBALL}\" /sdcard/linux/images.tar.gz"
echo ""
