#!/bin/bash
# 30-configure-system.sh
# Configures the system (fstab, services, users, etc.)

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Configuring System ===${NC}"

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")}"
BUILD_DIR="${BUILD_DIR:-${PROJECT_ROOT}/build}"
ROOTFS="${BUILD_DIR}/rootfs"
CONFIGS_DIR="${PROJECT_ROOT}/configs"
SYSTEMD_DIR="${PROJECT_ROOT}/systemd"

# Verify rootfs exists
if [[ ! -d "${ROOTFS}/usr" ]]; then
    echo "ERROR: Rootfs not found. Run 10-build-rootfs.sh first"
    exit 1
fi

# Copy configuration files
echo "Installing configuration files..."

# fstab
echo "  - fstab"
sudo cp "${CONFIGS_DIR}/fstab" "${ROOTFS}/etc/fstab"

# hostname
echo "  - hostname"
sudo cp "${CONFIGS_DIR}/hostname" "${ROOTFS}/etc/hostname"

# locale
echo "  - locale"
sudo cp "${CONFIGS_DIR}/locale.conf" "${ROOTFS}/etc/locale.conf"
sudo cp "${CONFIGS_DIR}/vconsole.conf" "${ROOTFS}/etc/vconsole.conf"

# systemd-networkd
echo "  - systemd-networkd"
sudo mkdir -p "${ROOTFS}/etc/systemd/network"
sudo cp "${CONFIGS_DIR}/systemd-networkd/"*.network "${ROOTFS}/etc/systemd/network/"

# avahi
echo "  - avahi"
sudo mkdir -p "${ROOTFS}/etc/avahi/services"
sudo cp "${CONFIGS_DIR}/avahi/avahi-daemon.conf" "${ROOTFS}/etc/avahi/"
sudo cp "${CONFIGS_DIR}/avahi/services/"*.service "${ROOTFS}/etc/avahi/services/"

# sudoers
echo "  - sudoers"
sudo mkdir -p "${ROOTFS}/etc/sudoers.d"
sudo cp "${CONFIGS_DIR}/sudoers.d/10-wheel-nopasswd" "${ROOTFS}/etc/sudoers.d/"
sudo chmod 0440 "${ROOTFS}/etc/sudoers.d/10-wheel-nopasswd"

# sysctl
echo "  - sysctl"
sudo mkdir -p "${ROOTFS}/etc/sysctl.d"
sudo cp "${CONFIGS_DIR}/sysctl.d/"*.conf "${ROOTFS}/etc/sysctl.d/"

# zram
echo "  - zram-generator"
sudo cp "${CONFIGS_DIR}/zram-generator.conf" "${ROOTFS}/etc/systemd/zram-generator.conf"

# Install systemd service files
echo "Installing systemd services..."
sudo mkdir -p "${ROOTFS}/etc/systemd/system"
sudo cp "${SYSTEMD_DIR}/"*.service "${ROOTFS}/etc/systemd/system/"

# Create mount points
echo "Creating mount points..."
sudo mkdir -p "${ROOTFS}/mnt"/{internal,shared,backup}

# Configure locale generation
echo "Configuring locale..."
sudo sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' "${ROOTFS}/etc/locale.gen"
sudo arch-chroot "${ROOTFS}" locale-gen

# Enable essential services
echo "Enabling services..."
sudo arch-chroot "${ROOTFS}" systemctl enable systemd-networkd
sudo arch-chroot "${ROOTFS}" systemctl enable systemd-resolved
sudo arch-chroot "${ROOTFS}" systemctl enable avahi-daemon
sudo arch-chroot "${ROOTFS}" systemctl enable sshd

# Enable AVF services
AVF_SERVICES=(
    ttyd-avf
    avf-forwarder-guest-launcher
    avf-shutdown-runner
    avf-storage-balloon-agent
)

for service in "${AVF_SERVICES[@]}"; do
    echo "  - ${service}"
    sudo arch-chroot "${ROOTFS}" systemctl enable "${service}" 2>/dev/null || {
        echo -e "${YELLOW}    WARNING: Could not enable ${service}${NC}"
    }
done

# Create default user 'droid'
echo "Creating default user 'droid'..."
sudo arch-chroot "${ROOTFS}" useradd -m -G wheel -s /bin/bash droid || true
sudo arch-chroot "${ROOTFS}" passwd -d droid  # No password

# Set root password to blank (for emergency console)
echo "Setting root password..."
sudo arch-chroot "${ROOTFS}" passwd -d root

# Configure systemd-resolved with systemd-networkd
echo "Linking resolv.conf to systemd-resolved..."
sudo rm -f "${ROOTFS}/etc/resolv.conf"
sudo arch-chroot "${ROOTFS}" ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Configure mDNS resolution
echo "Configuring mDNS resolution..."
if sudo grep -q "^hosts:" "${ROOTFS}/etc/nsswitch.conf"; then
    sudo sed -i 's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns/' \
        "${ROOTFS}/etc/nsswitch.conf"
fi

# Disable unnecessary services to save resources
echo "Disabling unnecessary services..."
DISABLE_SERVICES=(
    systemd-timesyncd  # Will use NTP from DHCP if needed
)

for service in "${DISABLE_SERVICES[@]}"; do
    sudo arch-chroot "${ROOTFS}" systemctl disable "${service}" 2>/dev/null || true
done

# Clean up
echo "Cleaning up..."
sudo rm -rf "${ROOTFS}/var/cache/pacman/pkg/"*
sudo rm -rf "${ROOTFS}/var/lib/pacman/sync/"*
sudo rm -rf "${ROOTFS}/tmp/"*

echo ""
echo -e "${GREEN}=== System Configured ===${NC}"
echo "Default user: droid (no password, sudo access)"
echo "Root user: root (no password)"
echo ""
