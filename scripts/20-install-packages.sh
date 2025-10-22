#!/bin/bash
# 20-install-packages.sh
# Installs essential packages and AVF-specific packages into rootfs

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Installing Packages ===${NC}"

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")}"
BUILD_DIR="${BUILD_DIR:-${PROJECT_ROOT}/build}"
REPO_DIR="${REPO_DIR:-${PROJECT_ROOT}/repo}"
ROOTFS="${BUILD_DIR}/rootfs"

# Verify rootfs exists
if [[ ! -d "${ROOTFS}/usr" ]]; then
    echo "ERROR: Rootfs not found. Run 10-build-rootfs.sh first"
    exit 1
fi

# Copy local AVF repository to rootfs if it exists
if [[ -d "${REPO_DIR}/aarch64" ]]; then
    echo "Setting up local AVF repository..."
    sudo mkdir -p "${ROOTFS}/var/local-repo"
    sudo cp -r "${REPO_DIR}/aarch64"/* "${ROOTFS}/var/local-repo/"

    # Add local repository to pacman.conf
    if ! sudo grep -q "\[avf\]" "${ROOTFS}/etc/pacman.conf"; then
        sudo tee -a "${ROOTFS}/etc/pacman.conf" > /dev/null <<EOF

# Local AVF packages repository
[avf]
SigLevel = Optional TrustAll
Server = file:///var/local-repo
EOF
    fi

    # Update package database
    sudo arch-chroot "${ROOTFS}" pacman -Sy --noconfirm
fi

# Essential packages
echo "Installing essential packages..."
ESSENTIAL_PKGS=(
    # Base system
    base
    base-devel

    # Kernel (will be replaced by linux-avf)
    linux-aarch64

    # Boot
    systemd
    systemd-sysvcompat

    # Filesystem
    e2fsprogs
    dosfstools

    # Network
    avahi
    nss-mdns

    # Utilities
    sudo
    vim
    nano
    openssh
    git
    wget
    curl
    htop

    # Compression
    pigz
    zstd
)

sudo arch-chroot "${ROOTFS}" pacman -S --noconfirm --needed --overwrite '*' "${ESSENTIAL_PKGS[@]}"

# AVF-specific packages (if available in local repo)
echo "Installing AVF packages..."
AVF_PKGS=(
    linux-avf
    systemd-avf
    avf-forwarder-guest
    avf-forwarder-guest-launcher
    avf-shutdown-runner
    avf-storage-balloon-agent
    avf-ttyd
)

# Install AVF packages
sudo arch-chroot "${ROOTFS}" pacman -S --noconfirm --overwrite '*' "${AVF_PKGS[@]}" || {
    echo -e "${YELLOW}WARNING: Some AVF packages failed to install${NC}"
}

# Optional packages for development/debugging
if [[ "${INSTALL_DEV:-no}" == "yes" ]]; then
    echo "Installing development packages..."
    DEV_PKGS=(
        gdb
        strace
        tcpdump
        iperf3
        tmux
        screen
    )
    sudo arch-chroot "${ROOTFS}" pacman -S --noconfirm --needed "${DEV_PKGS[@]}"
fi

# Clean package cache to save space
echo "Cleaning package cache..."
sudo arch-chroot "${ROOTFS}" pacman -Scc --noconfirm

echo ""
echo -e "${GREEN}=== Packages Installed ===${NC}"
echo ""
