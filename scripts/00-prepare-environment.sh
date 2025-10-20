#!/bin/bash
# 00-prepare-environment.sh
# Prepares the build environment and verifies all dependencies

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_ROOT}/build"
REPO_DIR="${PROJECT_ROOT}/repo"

echo -e "${GREEN}=== Preparing Build Environment ===${NC}"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}ERROR: Do not run this script as root!${NC}"
    echo "The script will use sudo when needed."
    exit 1
fi

# Check required commands
echo "Checking dependencies..."
REQUIRED_CMDS=(
    "pacstrap"      # For bootstrapping Arch ARM
    "git"           # For fetching sources
    "wget"          # For downloading files
    "parted"        # For disk partitioning
    "mkfs.vfat"     # For EFI partition
    "mkfs.ext4"     # For root partition
    "tune2fs"       # For filesystem tuning
    "fsck.fat"      # For FAT filesystem check
    "pigz"          # For parallel compression
    "dd"            # For disk operations
    "arch-chroot"   # For chrooting into ARM rootfs
    "systemd-nspawn" # Alternative to chroot
)

MISSING_CMDS=()
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_CMDS+=("$cmd")
    fi
done

if [[ ${#MISSING_CMDS[@]} -gt 0 ]]; then
    echo -e "${RED}ERROR: Missing required commands:${NC}"
    printf '%s\n' "${MISSING_CMDS[@]}"
    echo ""
    echo "On Arch Linux, install with:"
    echo "  sudo pacman -S arch-install-scripts git wget parted dosfstools e2fsprogs pigz systemd"
    exit 1
fi

# Check for ARM64 support
echo "Checking ARM64 support..."
if [[ $(uname -m) != "aarch64" ]]; then
    # Not native ARM64, check for QEMU support
    if [[ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]]; then
        echo -e "${YELLOW}WARNING: Not running on ARM64 and QEMU binfmt not detected${NC}"
        echo "You may need to install qemu-user-static-binfmt for cross-architecture builds"
        echo "On Arch: sudo pacman -S qemu-user-static-binfmt"
        echo ""
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo -e "${GREEN}✓ QEMU binfmt detected, can build ARM64${NC}"
    fi
else
    echo -e "${GREEN}✓ Running on native ARM64${NC}"
fi

# Create build directories
echo "Creating build directories..."
mkdir -p "${BUILD_DIR}"/{rootfs,mnt/{efi,root}}
mkdir -p "${REPO_DIR}/aarch64"

# Check disk space
echo "Checking available disk space..."
AVAILABLE_SPACE=$(df "${BUILD_DIR}" | awk 'NR==2 {print $4}')
REQUIRED_SPACE=$((10 * 1024 * 1024)) # 10GB in KB

if [[ $AVAILABLE_SPACE -lt $REQUIRED_SPACE ]]; then
    echo -e "${RED}ERROR: Insufficient disk space${NC}"
    echo "Required: 10GB, Available: $((AVAILABLE_SPACE / 1024 / 1024))GB"
    exit 1
fi
echo -e "${GREEN}✓ Sufficient disk space available${NC}"

# Export environment variables for other scripts
export PROJECT_ROOT
export BUILD_DIR
export REPO_DIR
export SCRIPT_DIR

echo ""
echo -e "${GREEN}=== Environment Ready ===${NC}"
echo "Project root: ${PROJECT_ROOT}"
echo "Build directory: ${BUILD_DIR}"
echo "Repository: ${REPO_DIR}"
echo ""
