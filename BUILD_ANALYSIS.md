# NixOS AVF Build Process Analysis

## Overview

This document analyzes the NixOS AVF (Android Virtualization Framework) build process to guide the adaptation for Arch Linux ARM.

**Source Repository**: nixos-avf (NixOS implementation)
**Target**: Arch Linux ARM build for AVF
**AVF Upstream**: https://android.googlesource.com/platform/packages/modules/Virtualization/

## What is AVF?

Android Virtualization Framework is a virtualization environment for Android that provides:
- Terminal app (starting from Android 15 QPR2)
- Virtualized Linux environment within Android
- Uses virtio for filesystem sharing, networking, and device access
- Runs on Android 15+ (with Terminal patches) or Android 16+

## Build Architecture

### 1. Source Dependencies

**Primary Source**:
```
https://android.googlesource.com/platform/packages/modules/Virtualization/
Revision: android-16.0.0_r2
```

Location in code: `avf/default.nix:10-14`

The build fetches Android's AVF repository which contains:
- Debian build scripts (used as reference)
- Kernel patches for AVF support
- Guest service implementations (Rust)
- ttyd patches for client certificates and accessibility

### 2. Key Components

#### A. Guest Services (Rust-based)

Location: `avf/pkgs.nix`

Four Rust services are built from the AVF repository:

1. **forwarder_guest** (`guest/forwarder_guest/`)
   - Handles port forwarding between guest and host
   - Uses gRPC for communication

2. **forwarder_guest_launcher** (`guest/forwarder_guest_launcher/`)
   - Launches and manages forwarder_guest instances
   - Patched with `guest-tcpstates.patch` for TCP state monitoring
   - Requires BCC (BPF Compiler Collection) for eBPF functionality

3. **shutdown_runner** (`guest/shutdown_runner/`)
   - Manages VM shutdown sequences
   - Communicates via gRPC

4. **storage_balloon_agent** (`guest/storage_balloon_agent/`)
   - Dynamic memory management via ballooning
   - Allows Android to reclaim guest memory when needed

All services:
- Built using Rust/Cargo
- Use protobuf for API definitions
- Connect via gRPC on port file `/mnt/internal/debian_service_port`
- Run as systemd services
- Configured to restart on failure

#### B. ttyd (Terminal Daemon)

Location: `avf/pkgs.nix:48-60`

Modified ttyd with patches from AVF:
- **libwebsockets patch**: `client_cert.patch` - Adds client certificate authentication
- **ttyd patch**: `xtermjs_a11y.patch` - Accessibility improvements for xterm.js

Configuration (`avf/default.nix:145-163`):
- SSL enabled with certificates from `/mnt/internal/ca.crt`
- Port 7681
- Published via Avahi/mDNS for discovery
- Automatic login as default user (no password)

#### C. Kernel Modifications

Location: `avf/default.nix:239-257`

**Base Kernel**: Linux 6.1 (linuxPackages_6_1)

**Patches**:
- `avf/arm64-balloon.patch` from AVF repository
- Enables memory ballooning for ARM64

**Kernel Config** (structuredExtraConfig):
```nix
SND_VIRTIO = module    # Virtio sound support
SND = yes
SOUND = yes
```

**Kernel Modules**:
- `vhost_vsock` - Virtio socket for host-guest communication

**Kernel Parameters**:
- `console=tty1`
- `console=ttyS0` - Serial console for debugging

#### D. Systemd Modifications

Location: `avf/default.nix:139-143`

**Patch**: `systemd-esp-type-ignore.patch`
- Comments out EFI System Partition type validation
- AVF uses custom partition GUIDs that don't match standard ESP GUID
- Allows systemd-boot to work with non-standard partition types

### 3. Filesystem Structure

#### Disk Layout (GPT with EFI partition table)

```
/dev/vda1 - EFI System Partition (ESP)
  Label: ESP
  Contents: systemd-boot, kernel, initrd

/dev/vda2 - Root filesystem
  Label: nixos
  Filesystem: ext4
  Auto-resize enabled
```

#### Mount Points

```
/                 - /dev/disk/by-label/nixos (ext4, auto-resize)
/boot             - /dev/disk/by-label/ESP (vfat)
/mnt/internal     - virtiofs mount (shared with Android VM framework)
/mnt/shared       - virtiofs mount (Android shared storage /storage/emulated)
```

The `/mnt/internal` mount is critical - it contains:
- CA certificate for SSL
- gRPC port file for service communication
- VM configuration

### 4. Build Process Flow

#### Step 1: Fetch AVF Sources
```nix
pkgs.fetchgit {
  url = "https://android.googlesource.com/platform/packages/modules/Virtualization/";
  rev = "android-16.0.0_r2";
}
```

#### Step 2: Build Rust Services
Each service is built using `rustPlatform.buildRustPackage`:
- Extract from `guest/<service_name>/` in AVF repo
- Apply Cargo.lock files (checked into nixos-avf repo)
- Build with protobuf support
- Install to Nix store

#### Step 3: Build Modified ttyd
- Apply patches to libwebsockets
- Apply patches to ttyd
- Build with SSL support

#### Step 4: Create NixOS Configuration
The configuration (`avf/default.nix`) defines:
- Boot loader (systemd-boot)
- Kernel (6.1 with AVF patches)
- Services (ttyd, AVF guest services, Avahi)
- Filesystem mounts
- User setup (default user "droid" with sudo access, no password)
- Network configuration (systemd-networkd, DHCP)
- Firewall rules (port 7681 for ttyd)

#### Step 5: Build Disk Image
Location: `avf/finish.nix`

Process:
1. Create raw disk image with `make-disk-image.nix`
   - Partition table: EFI (GPT)
   - Memory for build: 2048 MB
   - Additional space: 4G
   - Channel copying disabled (saves space)

2. Extract partitions from disk image
   ```bash
   dd if=$diskImage of=efi_part bs=512 skip=<offset> count=<size>
   dd if=$diskImage of=root_part bs=512 skip=<offset> count=<size>
   ```

3. Fix filesystem compatibility
   ```bash
   tune2fs -O ^orphan_file root_part  # Android e2fsck doesn't support orphan_file
   fsck.fat -v -a efi_part            # Verify FAT filesystem
   ```

4. Generate VM configuration
   - Template: `vm_config.json` (from `avf.vmConfig` option)
   - Replace `{efi_part_guid}` and `{root_part_guid}` with actual UUIDs
   - Configuration includes:
     - Disk partition paths and GUIDs
     - Memory allocation (4096 MiB)
     - CPU topology (match_host)
     - Network enabled
     - GPU backend (2D)
     - Shared paths (Android storage, app data)

5. Create final tarball
   ```bash
   tar cv -I pigz -f $out build_id efi_part root_part vm_config.json [extra_files]
   ```

   Contents:
   - `build_id` - Contains output path and release year
   - `efi_part` - EFI partition image (binary)
   - `root_part` - Root partition image (binary)
   - `vm_config.json` - VM configuration for AVF
   - `README.md` - Installation instructions

#### Step 6: Initial Image Setup
Location: `initial/default.nix`

For first-boot image, additional setup:
1. Copy configuration files on first boot (activation script)
2. Create mount points `/mnt/{shared,internal,backup}`
3. Set up Nix channels
   - nixos-avf channel (for AVF modules)
   - nixos channel (for packages)
4. Generate default `/etc/nixos/configuration.nix`

### 5. VM Configuration Details

The `vm_config.json` configures AVF's VirtualizationService:

```json
{
  "name": "nixos",
  "disks": [
    {
      "partitions": [
        { "label": "ESP", "path": "$PAYLOAD_DIR/efi_part", "writable": true },
        { "label": "nixos", "path": "$PAYLOAD_DIR/root_part", "writable": true }
      ],
      "writable": true
    }
  ],
  "sharedPath": [
    { "sharedPath": "/storage/emulated" },
    { "sharedPath": "$APP_DATA_DIR/files" }
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
  "gpu": { "backend": "2d" }
}
```

Key settings:
- `protected: false` - Not a protected VM (allows debugging)
- `debuggable: true` - Enables console access
- `auto_memory_balloon: true` - Dynamic memory management
- `cpu_topology: "match_host"` - Use same CPU count as phone

### 6. Network and Service Discovery

**Network Stack**:
- systemd-networkd for network management
- DHCP enabled (provided by AVF)
- nftables firewall
- IPv4 only (IPv6 disabled in Avahi to avoid connection issues)

**Service Discovery**:
- Avahi daemon publishes mDNS services
- ttyd published as `_http._tcp` on port 7681
- Terminal app discovers VM via mDNS
- SSL with client certificate authentication

### 7. Service Configuration

All AVF guest services follow the same pattern:

```nix
mkService = name: {
  serviceConfig = {
    ExecStart = "${android_virt.${name}} --grpc-port-file /mnt/internal/debian_service_port";
    Type = "simple";
    Restart = "on-failure";
    RestartSec = 1;
    User = "root";
    Group = "root";
  };
  wantedBy = [ "multi-user.target" ];
  wants = [ "network-online.target" ];
  after = [ "network-online.target", "network.target", "mnt-internal.mount" ];
};
```

Services wait for `/mnt/internal` to be mounted (critical for gRPC communication).

### 8. Build Commands

**Building the initial image**:
```bash
# For ARM64 on x86_64 host
export CROSS_SYSTEM=aarch64_linux
nix-build initial.nix -A config.system.build.avfImage
```

Output: `result` symlink pointing to `.tar.gz` file

**Using Flakes**:
```bash
nix build .#nixosModules.avfInitial
```

### 9. Installation Process

**On Debuggable Android**:
1. Place image at `/sdcard/linux/images.tar.gz`
2. Clear existing VM data:
   ```bash
   rm -rfv /data/data/com.android.virtualization.terminal/{files/*,vm/*}
   ```
3. Launch Terminal app
4. App auto-installs from images.tar.gz

**On Production Android (with root)**:
1. Enable debuggable mode: `magisk resetprop ro.debuggable 1; stop; start;`
2. Download and place image
3. Launch Terminal app
4. Revert debuggable mode after installation

**Image Location**:
- User-accessible: `/sdcard/linux/images.tar.gz` → `/data/media/0/linux/images.tar.gz`
- App data: `/data/data/com.android.virtualization.terminal/`

### 10. Key Differences from Standard Linux

1. **Partition GUIDs**: Uses custom GUIDs, not standard EFI GUID
2. **Filesystem features**: Android's e2fsck doesn't support `orphan_file`
3. **Memory management**: 4GB allocation but actual usage limited by phone RAM
4. **No direct console**: Access only via ttyd over network
5. **Certificate-based auth**: SSL with client certificates from Android
6. **Service communication**: All services use gRPC via shared port file

## Dependencies Summary

### Build-time:
- Nix package manager
- Rust toolchain (via rustPlatform)
- protobuf compiler
- Cross-compilation support (for ARM64)
- Internet access (to fetch AVF sources)

### Runtime (in guest):
- Linux kernel 6.1 with AVF patches
- systemd (with ESP type ignore patch)
- ttyd (with AVF patches)
- AVF guest services (4 Rust binaries)
- Avahi (mDNS)
- BCC (for forwarder_guest_launcher)
- Standard utilities (coreutils, util-linux, etc.)

### Runtime (on Android host):
- Android 15+ with Terminal app patches or Android 16+
- AVF/VirtualizationService
- Debuggable mode (for initial install only)

## References

- AVF Source: https://android.googlesource.com/platform/packages/modules/Virtualization/
- Debian Build Scripts: `build/debian/` in AVF repo
- NixOS AVF: https://github.com/nix-community/nixos-avf
