# Arch Linux ARM AVF Adaptation Plan

## Goal

Adapt the NixOS AVF build process to create an Arch Linux ARM image that can run in Android's Virtualization Framework.

## Target Architecture

- **Distribution**: Arch Linux ARM (https://archlinuxarm.org/)
- **Architecture**: aarch64 (ARM64)
- **Kernel**: Custom kernel with AVF patches
- **Init System**: systemd (same as NixOS)
- **Target Device**: Android phones with AVF support (Android 15+/16+)

## Translation Strategy: Nix → Arch

| NixOS Concept | Arch Linux Equivalent |
|--------------|----------------------|
| `.nix` files | PKGBUILD + shell scripts |
| `pkgs.fetchgit` | git clone / source array in PKGBUILD |
| `rustPlatform.buildRustPackage` | PKGBUILD with Rust build steps |
| Nix store | `/usr/local` or `/opt/avf` |
| systemd services (Nix) | systemd unit files in `/etc/systemd/system/` |
| `make-disk-image.nix` | Shell script with dd, mkfs, etc. |
| Nix channels | pacman repos + custom repo |
| `configuration.nix` | Configuration files in `/etc/` |

## Component Breakdown

### 1. AVF Guest Services (Rust)

**Source**: Android AVF repository guest services

**Approach**: Create PKGBUILDs for each service

**Files to create**:
```
pkgbuilds/
├── avf-forwarder-guest/
│   └── PKGBUILD
├── avf-forwarder-guest-launcher/
│   ├── PKGBUILD
│   └── guest-tcpstates.patch
├── avf-shutdown-runner/
│   └── PKGBUILD
└── avf-storage-balloon-agent/
    └── PKGBUILD
```

**Common PKGBUILD structure**:
```bash
pkgname=avf-<service>
pkgver=16.0.0_r2
pkgrel=1
arch=('aarch64')
depends=('gcc-libs' 'protobuf')
makedepends=('rust' 'cargo' 'protobuf' 'git')
source=("avf::git+https://android.googlesource.com/platform/packages/modules/Virtualization#tag=android-16.0.0_r2")

build() {
    cd "$srcdir/avf/guest/<service>"
    cargo build --release
}

package() {
    install -Dm755 "target/release/<service>" "$pkgdir/usr/bin/<service>"
}
```

**Dependencies**:
- `rust`
- `cargo`
- `protobuf`
- `gcc-libs`

**Installation location**: `/usr/bin/`

### 2. Modified ttyd

**Source**: ttyd with AVF patches

**Approach**: Custom PKGBUILD with patches

**File structure**:
```
pkgbuilds/avf-ttyd/
├── PKGBUILD
├── client_cert.patch
└── xtermjs_a11y.patch
```

**PKGBUILD considerations**:
- Base on official ttyd package
- Apply libwebsockets patch before building ttyd
- May need to build libwebsockets from source with patch
- Install to `/usr/bin/ttyd-avf` (to not conflict with main ttyd)

**Dependencies**:
- `cmake`
- `json-c`
- `openssl`
- `zlib`
- `vim` (for xxd)
- Modified libwebsockets

### 3. Custom Kernel

**Source**: Linux 6.1 with AVF balloon patch

**Options**:

#### Option A: Custom kernel package (Recommended)
```
pkgbuilds/linux-avf/
├── PKGBUILD
├── config (based on linux-aarch64 config)
├── arm64-balloon.patch
└── linux.preset
```

- Base on `linux-aarch64` PKGBUILD
- Apply AVF balloon patch
- Enable required config options:
  - `CONFIG_SND_VIRTIO=m`
  - `CONFIG_SND=y`
  - `CONFIG_SOUND=y`
  - `CONFIG_VHOST_VSOCK=m`
  - Other virtio drivers as needed

#### Option B: DKMS module (Alternative)
- Keep stock kernel
- Package AVF-specific features as DKMS modules
- Less invasive but may have limitations

**Recommendation**: Option A (custom kernel) for full compatibility

### 4. Systemd Service Files

**Location**: `/etc/systemd/system/`

**Files to create**:
```
systemd/
├── ttyd-avf.service
├── avf-forwarder-guest-launcher.service
├── avf-shutdown-runner.service
├── avf-storage-balloon-agent.service
└── avahi-ttyd.service
```

**Example service file** (avf-forwarder-guest-launcher.service):
```ini
[Unit]
Description=AVF Forwarder Guest Launcher
After=network-online.target network.target mnt-internal.mount
Wants=network-online.target
RequiresMountsFor=/mnt/internal

[Service]
Type=simple
ExecStart=/usr/bin/forwarder_guest_launcher --grpc-port-file /mnt/internal/debian_service_port
Restart=on-failure
RestartSec=1
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 5. Image Building Scripts

**Approach**: Shell scripts to create the disk image and package

**Scripts to create**:
```
scripts/
├── 00-prepare-environment.sh
├── 10-build-rootfs.sh
├── 20-install-packages.sh
├── 30-configure-system.sh
├── 40-create-disk-image.sh
├── 50-package-image.sh
└── build-all.sh (orchestrates all steps)
```

#### 00-prepare-environment.sh
- Verify dependencies
- Create build directories
- Download AVF sources if needed

#### 10-build-rootfs.sh
- Create temporary rootfs directory
- Use pacstrap or similar to bootstrap Arch ARM
- Install base packages

#### 20-install-packages.sh
- Install AVF packages (built from PKGBUILDs)
- Install kernel
- Install ttyd
- Install avahi and dependencies

#### 30-configure-system.sh
- Create fstab with virtiofs mounts
- Set up systemd-boot
- Install systemd service files
- Configure networking (systemd-networkd)
- Create default user
- Set up zram
- Configure firewall

#### 40-create-disk-image.sh
- Create disk image file
- Partition with GPT (EFI + root)
- Format partitions (vfat + ext4)
- Mount and copy rootfs
- Install systemd-boot
- Extract partition GUIDs

#### 50-package-image.sh
- Extract partitions as separate files
- Run tune2fs to disable orphan_file feature
- Run fsck.fat on EFI partition
- Generate vm_config.json with actual GUIDs
- Create tarball with pigz

### 6. System Configuration Files

**Files to create**:
```
configs/
├── fstab
├── systemd-networkd/
│   └── 80-dhcp.network
├── systemd-boot/
│   ├── loader.conf
│   └── entries/
│       └── arch.conf
├── avahi/
│   └── avahi-daemon.conf
├── sudoers.d/
│   └── wheel
└── sysctl.d/
    └── 99-avf.conf
```

#### fstab
```
# <device>              <mount>        <type>     <options>           <dump> <pass>
/dev/vda2               /              ext4       defaults            0      1
/dev/vda1               /boot          vfat       defaults            0      2
internal                /mnt/internal  virtiofs   defaults            0      0
android                 /mnt/shared    virtiofs   defaults            0      0
```

#### systemd-networkd/80-dhcp.network
```ini
[Match]
Name=en*

[Network]
DHCP=yes
IPv6AcceptRA=no

[DHCPv4]
UseDNS=yes
```

#### systemd-boot/loader.conf
```
default arch.conf
timeout 0
console-mode max
editor no
```

#### systemd-boot/entries/arch.conf
```
title   Arch Linux ARM (AVF)
linux   /vmlinuz-linux-avf
initrd  /initramfs-linux-avf.img
options root=LABEL=archarm rw console=tty1 console=ttyS0
```

### 7. VM Configuration Template

**File**: `configs/vm_config.json.template`

```json
{
  "name": "archarm",
  "disks": [
    {
      "partitions": [
        {
          "label": "ESP",
          "path": "$PAYLOAD_DIR/efi_part",
          "writable": true,
          "guid": "{EFI_PART_GUID}"
        },
        {
          "label": "archarm",
          "path": "$PAYLOAD_DIR/root_part",
          "writable": true,
          "guid": "{ROOT_PART_GUID}"
        }
      ],
      "writable": true
    }
  ],
  "sharedPath": [
    {
      "sharedPath": "/storage/emulated"
    },
    {
      "sharedPath": "$APP_DATA_DIR/files"
    }
  ],
  "protected": false,
  "cpu_topology": "match_host",
  "platform_version": "~1.0",
  "memory_mib": 4096,
  "debuggable": true,
  "console_out": true,
  "console_input_device": "ttyS0",
  "network": true,
  "auto_memory_balloon": true,
  "gpu": {
    "backend": "2d"
  }
}
```

### 8. Systemd Patch

**Issue**: systemd validates EFI partition GUID, AVF uses custom GUIDs

**Solutions**:

#### Option A: Patch systemd (like NixOS)
- Apply `systemd-esp-type-ignore.patch`
- Create PKGBUILD for patched systemd
- May complicate updates

#### Option B: Use systemd-boot hook
- Create hook to modify partition type temporarily
- Less invasive but fragile

#### Option C: Use different bootloader
- GRUB (works but slower boot)
- Not recommended (inconsistent with upstream AVF)

**Recommendation**: Option A (patch systemd) for consistency with NixOS implementation

### 9. Package Repository Setup

**Approach**: Host custom repository for AVF packages

**Structure**:
```
repo/
├── aarch64/
│   ├── linux-avf-<version>.pkg.tar.zst
│   ├── avf-forwarder-guest-<version>.pkg.tar.zst
│   ├── avf-forwarder-guest-launcher-<version>.pkg.tar.zst
│   ├── avf-shutdown-runner-<version>.pkg.tar.zst
│   ├── avf-storage-balloon-agent-<version>.pkg.tar.zst
│   ├── avf-ttyd-<version>.pkg.tar.zst
│   ├── systemd-avf-<version>.pkg.tar.zst (if patched)
│   └── aarch64.db.tar.gz (repository database)
└── build-repo.sh
```

**pacman.conf addition**:
```ini
[avf]
SigLevel = Optional TrustAll
Server = https://your-server.com/arch-avf/repo/$arch
```

**Alternative**: AUR packages (but requires users to build)

## Build Environment Requirements

### Host System:
- Arch Linux (recommended) or any Linux with:
  - arch-install-scripts (for pacstrap)
  - qemu-user-static-binfmt (for ARM64 chroot on x86_64)
  - parted, gdisk, dosfstools, e2fsprogs
  - pigz
  - git, wget
  - Sufficient disk space (~10GB for build)

### Build Flow:
```
1. Build all PKGBUILD packages → .pkg.tar.zst files
2. Create local repo with built packages
3. Bootstrap Arch ARM rootfs with pacstrap
4. Install AVF packages from local repo
5. Configure system
6. Create disk image
7. Package for AVF
```

## Implementation Phases

### Phase 1: Package Development (Weeks 1-2)
- [ ] Create PKGBUILD for each AVF guest service
- [ ] Test building on native ARM64 or with cross-compilation
- [ ] Create PKGBUILD for modified ttyd
- [ ] Create PKGBUILD for custom kernel
- [ ] (Optional) Create PKGBUILD for patched systemd

### Phase 2: System Configuration (Week 3)
- [ ] Create all systemd service files
- [ ] Create system configuration files (fstab, networkd, etc.)
- [ ] Create systemd-boot configuration
- [ ] Prepare vm_config.json template

### Phase 3: Build Scripts (Week 4)
- [ ] Write rootfs creation script
- [ ] Write package installation script
- [ ] Write system configuration script
- [ ] Write disk image creation script
- [ ] Write packaging script
- [ ] Test complete build process

### Phase 4: Testing (Week 5)
- [ ] Test image on Android 16 device
- [ ] Verify all services start correctly
- [ ] Test ttyd connection
- [ ] Test filesystem sharing
- [ ] Test memory balloon
- [ ] Document any issues and fixes

### Phase 5: Documentation & Distribution (Week 6)
- [ ] Write user installation guide
- [ ] Write developer build guide
- [ ] Set up package repository (GitHub releases or custom server)
- [ ] Create automated build CI/CD (GitHub Actions)
- [ ] Publish initial release

## Challenges & Solutions

### Challenge 1: Cross-compilation
**Problem**: Building ARM64 packages on x86_64 host
**Solutions**:
- Use qemu-user-static with binfmt_misc
- Set up remote ARM64 builder
- Use distcc with ARM64 workers
- Build natively on ARM64 device (slow but reliable)

### Challenge 2: Kernel Configuration
**Problem**: Determining all required kernel options
**Solutions**:
- Extract config from working NixOS build
- Compare with Android kernel configs
- Test iteratively with AVF

### Challenge 3: Package Updates
**Problem**: Keeping AVF packages in sync with upstream
**Solutions**:
- Pin to specific AVF version (android-16.0.0_r2)
- Create update script to pull new versions
- Monitor AVF repository for changes

### Challenge 4: Systemd Compatibility
**Problem**: Arch systemd updates may break patches
**Solutions**:
- Pin systemd version in custom package
- Regularly test new systemd versions
- Consider alternatives (bootloader switch, partition type modification)

### Challenge 5: Size Optimization
**Problem**: Minimal image size for faster downloads/installs
**Solutions**:
- Use minimal base installation
- Remove unnecessary packages
- Use compression (pigz, zstd)
- Separate base and full images

## Differences from NixOS Build

### Advantages of Arch Approach:
1. **Simpler build process** - No Nix learning curve
2. **Standard tools** - Familiar shell scripts and PKGBUILDs
3. **Easy debugging** - Standard filesystem layout
4. **Binary packages** - Fast installation, no compilation on device
5. **Community support** - Arch ARM has active community

### Disadvantages:
1. **No reproducibility** - Nix guarantees bit-for-bit reproduction
2. **Manual dependency management** - No automatic dependency resolution in build
3. **Update complexity** - Manual version bumps instead of Nix channels
4. **Less declarative** - Imperative scripts vs declarative Nix configs

## Testing Checklist

Before considering the build complete:

- [ ] Image boots in AVF on real device
- [ ] Serial console accessible via logcat/adb
- [ ] ttyd service starts and is discoverable via mDNS
- [ ] Can connect to ttyd from Terminal app
- [ ] Login works (default user, no password)
- [ ] Sudo works without password
- [ ] /mnt/internal and /mnt/shared are mounted
- [ ] Network connectivity (ping, DNS)
- [ ] All 4 AVF services running
- [ ] Disk auto-resize works
- [ ] pacman can install packages
- [ ] Can rebuild system (enough memory)
- [ ] Shutdown/restart works cleanly
- [ ] Disk expansion works (via Android settings)

## Resources & References

### Upstream Sources:
- AVF: https://android.googlesource.com/platform/packages/modules/Virtualization/
- Arch ARM: https://archlinuxarm.org/
- NixOS AVF: https://github.com/nix-community/nixos-avf

### Documentation:
- Arch Build System: https://wiki.archlinux.org/title/Arch_Build_System
- PKGBUILD: https://wiki.archlinux.org/title/PKGBUILD
- systemd-boot: https://wiki.archlinux.org/title/Systemd-boot
- systemd-networkd: https://wiki.archlinux.org/title/Systemd-networkd

### Similar Projects:
- Debian AVF build: `build/debian/` in AVF repository
- Android CuttleFish: https://github.com/google/android-cuttlefish

## Next Steps

After documenting the plan:
1. Review plan with stakeholders
2. Set up development environment
3. Begin Phase 1 (Package Development)
4. Create GitHub repository for arch-arm64-avf
5. Set up issue tracking for each task
