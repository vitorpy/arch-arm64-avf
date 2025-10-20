# Troubleshooting Guide

This guide covers common issues and their solutions for Arch Linux ARM on AVF.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Boot Problems](#boot-problems)
- [Network Issues](#network-issues)
- [Service Issues](#service-issues)
- [Performance Issues](#performance-issues)
- [Storage Issues](#storage-issues)
- [General Debugging](#general-debugging)

## Installation Issues

### Terminal App Says "Image Not Found"

**Symptoms**: Terminal app doesn't detect the image.

**Causes**:
- Image not placed in correct location
- Incorrect filename
- Device not in debuggable mode

**Solutions**:

1. Verify image location:
   ```bash
   adb shell ls -la /sdcard/linux/images.tar.gz
   ```

2. Ensure correct path:
   ```bash
   # Should be exactly this path
   adb push image-*.tar.gz /sdcard/linux/images.tar.gz
   ```

3. Check device debuggable status:
   ```bash
   adb shell getprop ro.debuggable
   # Should return "1"
   ```

### Image Won't Extract

**Symptoms**: Terminal app stuck at "Installing..."

**Causes**:
- Corrupted download
- Insufficient storage
- SELinux blocking extraction

**Solutions**:

1. Verify image integrity:
   ```bash
   # On computer
   sha256sum image-*.tar.gz
   # Compare with .sha256 file
   ```

2. Check device storage:
   ```bash
   adb shell df -h /data
   # Need at least 8GB free
   ```

3. Check SELinux:
   ```bash
   adb shell getenforce
   # Try: adb shell su -c "setenforce 0"
   ```

### ADB Push Fails

**Symptoms**: `adb push` command errors.

**Solutions**:

1. Check ADB connection:
   ```bash
   adb devices
   # Should show your device
   ```

2. Restart ADB server:
   ```bash
   adb kill-server
   adb start-server
   adb devices
   ```

3. Use smaller chunks (if timeout):
   ```bash
   # Split and push
   split -b 100M image-*.tar.gz part_
   adb push part_* /sdcard/linux/
   adb shell "cat /sdcard/linux/part_* > /sdcard/linux/images.tar.gz"
   ```

## Boot Problems

### VM Won't Start

**Symptoms**: Terminal app shows error or infinite loading.

**Check logs**:
```bash
adb logcat | grep -i "virtualization\|crosvm\|vm"
```

**Common causes and solutions**:

1. **Kernel panic**:
   ```
   Look for: "Kernel panic - not syncing"
   Solution: Kernel incompatibility, need to rebuild with correct config
   ```

2. **Missing partitions**:
   ```
   Look for: "Failed to open disk"
   Solution: Reinstall image, ensure vm_config.json is correct
   ```

3. **Insufficient memory**:
   ```
   Look for: "failed to allocate memory"
   Solution: Close other apps, increase VM memory in Terminal settings
   ```

### Boot Hangs at "Loading initial ramdisk..."

**Symptoms**: Boot process stops at initramfs.

**Solutions**:

1. Check initramfs exists:
   ```bash
   # Mount EFI partition and verify
   ls -la /boot/initramfs-linux-avf.img
   ```

2. Regenerate initramfs:
   ```bash
   sudo mkinitcpio -p linux-avf
   ```

3. Check kernel command line:
   ```bash
   cat /boot/loader/entries/arch.conf
   # Should have: root=LABEL=archarm rw
   ```

### Console Shows Errors

**Symptoms**: Boot errors visible in console.

**View console output**:
```bash
# Via ADB
adb shell "cat /data/local/tmp/terminal-*.log"

# Via logcat
adb logcat -s crosvm:* VirtualizationService:*
```

## Network Issues

### No Network Connectivity

**Symptoms**: Can't ping, no internet access.

**Diagnostic steps**:

1. Check interface is up:
   ```bash
   ip addr show
   # Should show enp0s1 or similar with IP
   ```

2. Check DHCP:
   ```bash
   sudo systemctl status systemd-networkd
   sudo networkctl status
   ```

3. Restart networking:
   ```bash
   sudo systemctl restart systemd-networkd
   sudo systemctl restart systemd-resolved
   ```

4. Check AVF provides DHCP:
   ```bash
   sudo journalctl -u systemd-networkd
   # Look for DHCP messages
   ```

### DNS Resolution Fails

**Symptoms**: Can ping IPs but not domain names.

**Solutions**:

1. Check resolv.conf:
   ```bash
   cat /etc/resolv.conf
   # Should point to 127.0.0.53
   ```

2. Fix symlink:
   ```bash
   sudo rm /etc/resolv.conf
   sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
   ```

3. Restart resolved:
   ```bash
   sudo systemctl restart systemd-resolved
   ```

4. Test DNS:
   ```bash
   resolvectl query archlinux.org
   ```

### Can't Connect from Android Terminal

**Symptoms**: Terminal app can't find VM.

**Solutions**:

1. Check ttyd service:
   ```bash
   sudo systemctl status ttyd-avf
   sudo journalctl -u ttyd-avf
   ```

2. Check Avahi (mDNS):
   ```bash
   sudo systemctl status avahi-daemon
   ```

3. Verify service published:
   ```bash
   avahi-browse -a
   # Should show Terminal service
   ```

4. Restart services:
   ```bash
   sudo systemctl restart avahi-daemon
   sudo systemctl restart ttyd-avf
   ```

## Service Issues

### AVF Services Not Running

**Symptoms**: `systemctl status avf-*` shows inactive/failed.

**Common causes**:

1. **/mnt/internal not mounted**:
   ```bash
   mount | grep /mnt/internal
   # If missing:
   sudo mount -a
   ```

2. **gRPC port file missing**:
   ```bash
   ls -la /mnt/internal/debian_service_port
   # Should exist
   ```

3. **Service crashes**:
   ```bash
   sudo journalctl -u avf-forwarder-guest-launcher
   # Check for error messages
   ```

**Restart all AVF services**:
```bash
sudo systemctl restart avf-forwarder-guest-launcher
sudo systemctl restart avf-shutdown-runner
sudo systemctl restart avf-storage-balloon-agent
```

### SSH Won't Start

**Symptoms**: Can't connect via SSH.

**Solutions**:

1. Enable and start SSH:
   ```bash
   sudo systemctl enable sshd
   sudo systemctl start sshd
   ```

2. Check SSH is listening:
   ```bash
   sudo ss -tlnp | grep :22
   ```

3. Set password for droid:
   ```bash
   sudo passwd droid
   ```

4. Check SSH config:
   ```bash
   sudo vim /etc/ssh/sshd_config
   # Ensure PasswordAuthentication is yes
   ```

### Avahi/mDNS Not Working

**Symptoms**: Services not discoverable.

**Solutions**:

1. Check Avahi daemon:
   ```bash
   sudo systemctl status avahi-daemon
   ```

2. Check service files:
   ```bash
   ls -la /etc/avahi/services/
   ```

3. Test mDNS resolution:
   ```bash
   avahi-resolve -n archarm-avf.local
   ```

4. Ensure IPv6 disabled (AVF compatibility):
   ```bash
   cat /etc/avahi/avahi-daemon.conf
   # use-ipv6=no should be set
   ```

## Performance Issues

### System Very Slow

**Symptoms**: Sluggish response, high load.

**Diagnostic**:
```bash
# Check load
uptime

# Check memory
free -h

# Check processes
top
# Press 'P' to sort by CPU, 'M' for memory
```

**Solutions**:

1. **Increase VM memory**:
   - Android Terminal settings → VM Settings → Memory
   - Increase to 6GB or 8GB if possible

2. **Enable/check zram**:
   ```bash
   sudo systemctl status systemd-zram-setup@zram0.service
   lsblk  # Should show zram0
   ```

3. **Disable unnecessary services**:
   ```bash
   sudo systemctl disable <service-name>
   ```

4. **Close Android apps**:
   - Free up host memory

5. **Check balloon agent**:
   ```bash
   sudo systemctl status avf-storage-balloon-agent
   ```

### High Memory Usage

**Symptoms**: Out of memory errors, swapping heavily.

**Solutions**:

1. Check memory usage:
   ```bash
   ps aux --sort=-%mem | head -20
   ```

2. Clean package cache:
   ```bash
   sudo pacman -Scc
   ```

3. Limit journald:
   ```bash
   sudo journalctl --vacuum-size=50M
   ```

4. Increase swap:
   ```bash
   # Check zram config
   cat /etc/systemd/zram-generator.conf
   # Increase zram-size if needed
   ```

### Disk I/O Slow

**Symptoms**: File operations lag.

**Solutions**:

1. Check I/O wait:
   ```bash
   iostat -x 1
   ```

2. Use noatime mount option (should be default):
   ```bash
   cat /etc/fstab
   # Check for noatime
   ```

3. Close Android apps doing heavy I/O

4. Check if filesystem full:
   ```bash
   df -h
   ```

## Storage Issues

### Out of Disk Space

**Symptoms**: "No space left on device" errors.

**Solutions**:

1. Check usage:
   ```bash
   df -h
   du -sh /* | sort -rh
   ```

2. Clean up:
   ```bash
   # Package cache
   sudo pacman -Scc

   # Logs
   sudo journalctl --vacuum-time=3d

   # Orphaned packages
   sudo pacman -Rns $(pacman -Qtdq)

   # Temp files
   sudo rm -rf /tmp/*
   sudo rm -rf /var/tmp/*
   ```

3. Expand disk:
   - Terminal app settings → Increase disk size
   - Then: `sudo resize2fs /dev/vda2`

### Can't Access Android Storage

**Symptoms**: `/mnt/shared` empty or errors.

**Solutions**:

1. Check mount:
   ```bash
   mount | grep /mnt/shared
   ```

2. Remount:
   ```bash
   sudo mount -a
   ```

3. Check virtiofs:
   ```bash
   dmesg | grep virtiofs
   ```

4. Check fstab:
   ```bash
   cat /etc/fstab
   # Should have: android /mnt/shared virtiofs ...
   ```

### Filesystem Errors

**Symptoms**: Read-only filesystem, corruption messages.

**Solutions**:

1. Check filesystem:
   ```bash
   sudo fsck /dev/vda2
   # Run from recovery if needed
   ```

2. Check dmesg for errors:
   ```bash
   dmesg | grep -i "error\|corruption"
   ```

3. Remount read-write:
   ```bash
   sudo mount -o remount,rw /
   ```

## General Debugging

### Viewing Logs

**System logs**:
```bash
# Recent logs
sudo journalctl -n 100

# Follow logs
sudo journalctl -f

# Specific service
sudo journalctl -u ttyd-avf

# Boot logs
sudo journalctl -b

# Kernel logs
dmesg

# Error messages only
sudo journalctl -p err
```

**Android logs**:
```bash
# VM-related logs
adb logcat | grep -i "virtualization\|vm\|crosvm"

# Terminal app logs
adb logcat | grep Terminal

# All logs
adb logcat
```

### Rescue Mode

If system won't boot properly:

1. **Access via ADB**:
   ```bash
   adb logcat  # See what's failing
   ```

2. **Use Android Terminal app console**:
   - May provide basic access even if ttyd fails

3. **Reinstall image**:
   - Last resort if system is corrupted

### Debugging Services

**Check service status**:
```bash
systemctl status <service-name>
```

**View service logs**:
```bash
sudo journalctl -u <service-name> -f
```

**Restart service**:
```bash
sudo systemctl restart <service-name>
```

**Check dependencies**:
```bash
systemctl list-dependencies <service-name>
```

### Performance Profiling

**CPU usage**:
```bash
top
htop  # If installed
```

**Memory**:
```bash
free -h
vmstat 1
```

**Disk I/O**:
```bash
iostat -x 1
iotop  # If installed, requires root
```

**Network**:
```bash
iftop  # If installed
ss -s
```

## Getting More Help

If you can't solve the issue:

1. **Gather information**:
   ```bash
   # System info
   uname -a
   cat /etc/os-release

   # Services status
   systemctl status

   # Logs (last 100 lines of relevant services)
   sudo journalctl -n 100 -u ttyd-avf -u avf-*

   # Android logs
   adb logcat -d | grep -i virtualization > android_log.txt
   ```

2. **Open GitHub issue** with:
   - Device model and Android version
   - Image version/build date
   - Steps to reproduce
   - Relevant logs

3. **Check existing issues**:
   - Someone may have solved it already

## Known Issues

### systemd-boot Warning on Boot

**Symptom**: Warning about EFI partition type.

**Status**: Expected behavior, can be ignored. AVF uses custom partition GUIDs.

### Slow First Boot

**Symptom**: First boot takes longer than usual.

**Status**: Normal. System is expanding filesystem and initializing services.

### Memory Balloon Inactive

**Symptom**: Balloon agent shows warnings.

**Status**: Normal if Android doesn't need to reclaim memory. Only activates under memory pressure.

## Advanced Debugging

### Enable Debug Logging

For AVF services:
```bash
sudo systemctl edit avf-forwarder-guest-launcher.service
# Add:
# [Service]
# Environment="RUST_LOG=debug"
sudo systemctl daemon-reload
sudo systemctl restart avf-forwarder-guest-launcher
```

For systemd:
```bash
sudo systemctl log-level debug
```

### Analyzing Core Dumps

Enable core dumps:
```bash
sudo systemctl edit systemd-coredump.socket
# [Socket]
# Storage=external
ulimit -c unlimited
```

Analyze dumps:
```bash
coredumpctl list
coredumpctl debug <PID>
```

### Network Packet Capture

```bash
# Install tcpdump
sudo pacman -S tcpdump

# Capture packets
sudo tcpdump -i any -w capture.pcap

# Analyze
tcpdump -r capture.pcap
```

## Recovery Procedures

### Factory Reset

Remove all data and reinstall:
```bash
adb shell rm -rf /data/data/com.android.virtualization.terminal/*
# Then reinstall image
```

### Backup Important Data

Before major changes:
```bash
# Backup home directory
tar czf backup.tar.gz /home/droid

# Copy to Android storage
cp backup.tar.gz /mnt/shared/

# Pull via ADB
adb pull /sdcard/backup.tar.gz
```

### Emergency Console Access

If ttyd fails but VM boots:
- Check Android logcat for console output
- Some apps provide serial console access
- May need to rebuild image with SSH enabled by default
