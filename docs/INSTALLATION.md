# Installing Arch Linux ARM on AVF

This guide explains how to install the Arch Linux ARM image on an Android device with AVF support.

## Prerequisites

### Android Device Requirements

- **Android Version**: Android 15+ with Terminal patches OR Android 16+
- **Architecture**: ARM64 (AArch64)
- **AVF Support**: Device must support Android Virtualization Framework
- **Installation Method**:
  - Debuggable build (easiest), OR
  - Root access (Magisk)

### Verified Devices

Devices known to work:
- Google Pixel 6/7/8/9 series (Android 16 Beta)
- Devices running GrapheneOS with Terminal patches
- Any device with custom ROM that includes AVF/Terminal support

### Tools Required

- ADB (Android Debug Bridge) installed on computer
- USB cable to connect device
- Downloaded image tarball (`image-archarm-avf-*.tar.gz`)

## Installation Methods

### Method 1: Debuggable Android (Recommended)

This is the easiest method if your device is already in debuggable mode (developer builds, custom ROMs).

#### Step 1: Prepare Device

Enable USB debugging:
1. Go to Settings → About Phone
2. Tap "Build Number" 7 times to enable Developer Options
3. Go to Settings → Developer Options
4. Enable "USB Debugging"
5. Connect device to computer and authorize ADB access

#### Step 2: Copy Image to Device

```bash
# Create directory on device
adb shell mkdir -p /sdcard/linux

# Push image (replace with actual filename)
adb push image-archarm-avf-*.tar.gz /sdcard/linux/images.tar.gz
```

The transfer may take 5-15 minutes depending on image size and connection speed.

#### Step 3: Clear Existing VM (if any)

```bash
adb shell
rm -rfv /data/data/com.android.virtualization.terminal/files/*
rm -rfv /data/data/com.android.virtualization.terminal/vm/*
exit
```

#### Step 4: Launch Terminal App

1. Open the Terminal app on your Android device
2. The app will automatically detect and install the image from `/sdcard/linux/images.tar.gz`
3. Installation takes 2-5 minutes
4. Terminal will automatically connect when ready

### Method 2: Root Access (Magisk)

If your device is not debuggable but you have root via Magisk:

#### Step 1: Enable Debuggable Mode Temporarily

```bash
adb shell su -c "magisk resetprop ro.debuggable 1"
adb reboot
```

Wait for device to reboot (1-2 minutes).

#### Step 2: Install Image

Follow Method 1, Steps 2-4.

#### Step 3: Disable Debuggable Mode (Optional)

After successful installation:

```bash
adb shell su -c "magisk resetprop ro.debuggable 0"
adb reboot
```

### Method 3: Manual Installation (Advanced)

If you want to manually extract and install:

```bash
# Extract on computer
tar xzf image-archarm-avf-*.tar.gz

# Push individual files
adb push efi_part /sdcard/linux/
adb push root_part /sdcard/linux/
adb push vm_config.json /sdcard/linux/
adb push build_id /sdcard/linux/

# Move to app data directory (requires root)
adb shell su -c "cp /sdcard/linux/* /data/data/com.android.virtualization.terminal/files/"
```

## Post-Installation

### First Boot

On first boot, the system will:
1. Auto-resize root partition to use available disk space
2. Start all AVF guest services
3. Start ttyd terminal server
4. Publish mDNS service for discovery
5. Be ready for connection within 30-60 seconds

### Accessing the System

1. Open the Terminal app
2. VM should appear and auto-connect
3. You'll be automatically logged in as user `droid`

### Default Credentials

- **Username**: `droid`
- **Password**: None (passwordless login)
- **Sudo**: Enabled without password
- **Root**: Also passwordless (for emergency console)

### Verifying Installation

Check that everything is working:

```bash
# Check hostname
hostname

# Check running services
systemctl status ttyd-avf
systemctl status avf-*

# Check mounts
mount | grep /mnt

# Check network
ip addr
ping -c 3 8.8.8.8

# Check disk space
df -h
```

### Accessing Android Storage

Android shared storage is mounted at `/mnt/shared`:

```bash
# List Android files
ls /mnt/shared/0/

# Create a file visible in Android
echo "Hello from Linux" > /mnt/shared/0/test.txt
```

## Package Management

### Updating System

```bash
# Update package database
sudo pacman -Sy

# Upgrade all packages
sudo pacman -Syu

# Upgrade including AVF packages (if repo is configured)
sudo pacman -Syu
```

### Installing Packages

```bash
# Search for package
pacman -Ss package-name

# Install package
sudo pacman -S package-name

# Install multiple packages
sudo pacman -S vim git python nodejs
```

### Removing Packages

```bash
# Remove package
sudo pacman -R package-name

# Remove package and dependencies
sudo pacman -Rs package-name
```

## Disk Management

### Expanding Disk Size

The root partition auto-expands on first boot. To manually expand:

1. Shut down VM from Android Terminal app
2. Go to Terminal app settings → VM Settings
3. Increase disk size
4. Restart VM
5. Resize filesystem:
   ```bash
   sudo resize2fs /dev/vda2
   ```

### Checking Disk Usage

```bash
# Overall disk usage
df -h

# Directory sizes
du -sh /*

# Largest directories
du -h / | sort -rh | head -20
```

### Cleaning Up Space

```bash
# Clean package cache
sudo pacman -Scc

# Clean journal logs (keep last 3 days)
sudo journalctl --vacuum-time=3d

# Remove orphaned packages
sudo pacman -Rns $(pacman -Qtdq)
```

## Networking

### Check Network Status

```bash
# Check IP address
ip addr show

# Check routing
ip route

# Check DNS
cat /etc/resolv.conf

# Test connectivity
ping -c 3 archlinux.org
```

### SSH Access

SSH server is enabled by default:

```bash
# From Android terminal
ssh droid@localhost

# Set password for droid user first
sudo passwd droid

# From another device on same network (via port forwarding)
ssh -p 2222 droid@<phone-ip>
```

## Troubleshooting

### VM Won't Start

Check Android logs:
```bash
adb logcat | grep -i "virtualization\|vm"
```

### Can't Connect to Terminal

1. Check ttyd service:
   ```bash
   adb shell
   # Then in VM (if accessible):
   sudo systemctl status ttyd-avf
   ```

2. Check mDNS:
   ```bash
   sudo systemctl status avahi-daemon
   ```

3. Restart services:
   ```bash
   sudo systemctl restart ttyd-avf avahi-daemon
   ```

### No Network Connectivity

1. Check systemd-networkd:
   ```bash
   sudo systemctl status systemd-networkd
   ```

2. Restart networking:
   ```bash
   sudo systemctl restart systemd-networkd
   ```

3. Check DHCP:
   ```bash
   ip addr  # Should show IP address
   ```

### Can't Access Android Storage

1. Check if mounted:
   ```bash
   mount | grep /mnt/shared
   ```

2. Remount:
   ```bash
   sudo mount -a
   ```

3. Check fstab:
   ```bash
   cat /etc/fstab
   ```

### System Runs Out of Memory

1. Check memory usage:
   ```bash
   free -h
   ```

2. Enable/check zram:
   ```bash
   sudo systemctl status systemd-zram-setup@zram0.service
   ```

3. Increase VM memory in Terminal app settings

### System Too Slow

1. Reduce background services
2. Increase VM RAM allocation in app settings
3. Close unused Android apps
4. Consider using minimal package install

## Updating the Image

To update to a newer image:

### Method 1: Fresh Install

1. Back up important data from `/home/droid`
2. Copy backup to `/mnt/shared` or adb pull
3. Follow installation steps with new image
4. Restore backed up data

### Method 2: In-Place Update

If only packages changed:

```bash
# Update packages
sudo pacman -Syu

# Update AVF packages if available
sudo pacman -S linux-avf avf-* --needed
```

## Uninstallation

To remove the VM:

```bash
# Clear all VM data
adb shell
rm -rfv /data/data/com.android.virtualization.terminal/*

# Or from Android:
# Settings → Apps → Terminal → Clear Data
```

## Advanced Configuration

### Customizing Services

Edit systemd services:
```bash
sudo systemctl edit ttyd-avf.service
```

### Adding Startup Scripts

Create service files in `/etc/systemd/system/`:
```bash
sudo vim /etc/systemd/system/my-service.service
sudo systemctl enable my-service
```

### Changing Default User

1. Create new user:
   ```bash
   sudo useradd -m -G wheel newuser
   sudo passwd newuser
   ```

2. Edit ttyd service to use new user:
   ```bash
   sudo systemctl edit ttyd-avf.service
   ```

### Using Different Shell

```bash
# Install fish
sudo pacman -S fish

# Change shell
chsh -s /usr/bin/fish
```

## Getting Help

- Check the [TROUBLESHOOTING.md](TROUBLESHOOTING.md) guide
- View Android logs: `adb logcat | grep virtualization`
- Check VM console: `adb shell cat /data/local/tmp/terminal-*.log`
- Open an issue on GitHub with logs and device info

## Next Steps

- Install your favorite development tools
- Set up your development environment
- Explore the AUR (Arch User Repository)
- Customize your system configuration

Enjoy your Arch Linux ARM environment in AVF!
