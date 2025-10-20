#!/bin/bash
# 40-create-disk-image.sh
# Creates a GPT-partitioned disk image with EFI and root partitions

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Creating Disk Image ===${NC}"

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")}"
BUILD_DIR="${BUILD_DIR:-${PROJECT_ROOT}/build}"
ROOTFS="${BUILD_DIR}/rootfs"
DISK_IMAGE="${BUILD_DIR}/disk.img"

# Verify rootfs exists
if [[ ! -d "${ROOTFS}/usr" ]]; then
    echo "ERROR: Rootfs not found. Run previous scripts first"
    exit 1
fi

# Disk image size (8GB total)
DISK_SIZE_MB=8192
EFI_SIZE_MB=512
ROOT_SIZE_MB=7680  # Rest of disk

echo "Creating ${DISK_SIZE_MB}MB disk image..."
rm -f "${DISK_IMAGE}"
dd if=/dev/zero of="${DISK_IMAGE}" bs=1M count="${DISK_SIZE_MB}" status=progress

# Create GPT partition table
echo "Creating GPT partition table..."
sudo parted -s "${DISK_IMAGE}" mklabel gpt

# Create EFI partition (first 512MB)
echo "Creating EFI System Partition..."
sudo parted -s "${DISK_IMAGE}" mkpart ESP fat32 1MiB ${EFI_SIZE_MB}MiB
sudo parted -s "${DISK_IMAGE}" set 1 boot on

# Create root partition (remaining space)
echo "Creating root partition..."
sudo parted -s "${DISK_IMAGE}" mkpart primary ext4 ${EFI_SIZE_MB}MiB 100%

# Show partition table
sudo parted -s "${DISK_IMAGE}" print

# Set up loop device
echo "Setting up loop device..."
LOOP_DEV=$(sudo losetup --find --show --partscan "${DISK_IMAGE}")
echo "Loop device: ${LOOP_DEV}"

# Format partitions
echo "Formatting EFI partition..."
sudo mkfs.vfat -F 32 -n ESP "${LOOP_DEV}p1"

echo "Formatting root partition..."
sudo mkfs.ext4 -L archarm -F "${LOOP_DEV}p2"

# Mount partitions
echo "Mounting partitions..."
MNT_ROOT="${BUILD_DIR}/mnt/root"
MNT_EFI="${BUILD_DIR}/mnt/efi"

sudo mkdir -p "${MNT_ROOT}" "${MNT_EFI}"
sudo mount "${LOOP_DEV}p2" "${MNT_ROOT}"
sudo mkdir -p "${MNT_ROOT}/boot"
sudo mount "${LOOP_DEV}p1" "${MNT_EFI}"

# Copy rootfs to disk
echo "Copying root filesystem to disk..."
sudo rsync -aAXv "${ROOTFS}/" "${MNT_ROOT}/" \
    --exclude=/dev/* \
    --exclude=/proc/* \
    --exclude=/sys/* \
    --exclude=/tmp/* \
    --exclude=/run/* \
    --exclude=/mnt/* \
    --exclude=/media/* \
    --exclude=/lost+found

# Copy boot files to EFI partition
echo "Installing boot files..."
if [[ -f "${ROOTFS}/boot/vmlinuz-linux-avf" ]]; then
    sudo cp "${ROOTFS}/boot/vmlinuz-linux-avf" "${MNT_EFI}/"
    sudo cp "${ROOTFS}/boot/initramfs-linux-avf.img" "${MNT_EFI}/"
else
    echo -e "${YELLOW}WARNING: linux-avf kernel not found, using default kernel${NC}"
    sudo cp "${ROOTFS}/boot/vmlinuz-linux-aarch64" "${MNT_EFI}/vmlinuz-linux-avf"
    sudo cp "${ROOTFS}/boot/initramfs-linux-aarch64.img" "${MNT_EFI}/initramfs-linux-avf.img"
fi

# Install systemd-boot
echo "Installing systemd-boot bootloader..."
sudo mkdir -p "${MNT_EFI}/loader/entries"

# Copy bootloader config
sudo cp "${PROJECT_ROOT}/configs/systemd-boot/loader.conf" "${MNT_EFI}/loader/"
sudo cp "${PROJECT_ROOT}/configs/systemd-boot/entries/arch.conf" "${MNT_EFI}/loader/entries/"

# Install systemd-boot (EFI bootloader)
sudo bootctl --esp-path="${MNT_EFI}" install --no-variables || {
    echo -e "${YELLOW}WARNING: bootctl install failed, trying manual installation${NC}"
    # Manual systemd-boot installation for cross-arch builds
    sudo mkdir -p "${MNT_EFI}/EFI/systemd" "${MNT_EFI}/EFI/BOOT"
    if [[ -f "${ROOTFS}/usr/lib/systemd/boot/efi/systemd-bootaa64.efi" ]]; then
        sudo cp "${ROOTFS}/usr/lib/systemd/boot/efi/systemd-bootaa64.efi" \
            "${MNT_EFI}/EFI/systemd/systemd-bootaa64.efi"
        sudo cp "${ROOTFS}/usr/lib/systemd/boot/efi/systemd-bootaa64.efi" \
            "${MNT_EFI}/EFI/BOOT/BOOTAA64.EFI"
    fi
}

# Extract partition GUIDs for later use
echo "Extracting partition GUIDs..."
EFI_GUID=$(sudo blkid -s PARTUUID -o value "${LOOP_DEV}p1")
ROOT_GUID=$(sudo blkid -s PARTUUID -o value "${LOOP_DEV}p2")

echo "EFI partition GUID: ${EFI_GUID}"
echo "Root partition GUID: ${ROOT_GUID}"

# Save GUIDs for packaging script
echo "${EFI_GUID}" > "${BUILD_DIR}/efi_guid"
echo "${ROOT_GUID}" > "${BUILD_DIR}/root_guid"

# Unmount and cleanup
echo "Unmounting partitions..."
sudo umount "${MNT_EFI}"
sudo umount "${MNT_ROOT}"
sudo losetup -d "${LOOP_DEV}"

echo ""
echo -e "${GREEN}=== Disk Image Created ===${NC}"
echo "Image: ${DISK_IMAGE}"
echo "EFI GUID: ${EFI_GUID}"
echo "Root GUID: ${ROOT_GUID}"
echo ""
