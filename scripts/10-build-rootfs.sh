#!/bin/bash
# 10-build-rootfs.sh
# Bootstraps a minimal Arch Linux ARM root filesystem

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Building Root Filesystem ===${NC}"

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")}"
BUILD_DIR="${BUILD_DIR:-${PROJECT_ROOT}/build}"
ROOTFS="${BUILD_DIR}/rootfs"

# Clean existing rootfs if requested
if [[ -d "${ROOTFS}" && "${CLEAN:-no}" == "yes" ]]; then
    echo "Cleaning existing rootfs..."
    sudo rm -rf "${ROOTFS}"
    mkdir -p "${ROOTFS}"
fi

# Check if rootfs already exists
if [[ -d "${ROOTFS}/usr" ]]; then
    echo -e "${YELLOW}Rootfs already exists, skipping bootstrap${NC}"
    echo "Set CLEAN=yes to rebuild from scratch"
    exit 0
fi

echo "Creating rootfs directory..."
mkdir -p "${ROOTFS}"

# Download Arch Linux ARM base if needed
ARCH_ARM_TARBALL="${BUILD_DIR}/ArchLinuxARM-aarch64-latest.tar.gz"

if [[ ! -f "${ARCH_ARM_TARBALL}" ]]; then
    echo "Downloading Arch Linux ARM base..."
    wget -O "${ARCH_ARM_TARBALL}" \
        "http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
else
    echo "Using cached Arch Linux ARM tarball"
fi

echo "Extracting base system..."
sudo tar -xpf "${ARCH_ARM_TARBALL}" -C "${ROOTFS}"

# Disable CheckSpace in pacman (GitHub Actions/non-mount limitation)
echo "Configuring pacman..."
sudo sed -i 's/^CheckSpace/#CheckSpace/' "${ROOTFS}/etc/pacman.conf"

# Configure pacman to use ARM repos
echo "Configuring pacman mirrors..."
sudo tee "${ROOTFS}/etc/pacman.d/mirrorlist" > /dev/null <<EOF
# Arch Linux ARM mirror list
Server = http://mirror.archlinuxarm.org/\$arch/\$repo
EOF

# Initialize pacman keyring
echo "Initializing pacman keyring..."
sudo arch-chroot "${ROOTFS}" /bin/bash <<'CHROOT'
pacman-key --init
pacman-key --populate archlinuxarm
CHROOT

# Update package database
echo "Updating package database..."
sudo arch-chroot "${ROOTFS}" pacman -Sy --noconfirm

echo ""
echo -e "${GREEN}=== Root Filesystem Ready ===${NC}"
echo "Location: ${ROOTFS}"
echo ""
