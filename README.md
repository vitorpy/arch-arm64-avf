# Arch Linux ARM for Android Virtualization Framework (AVF)

> **Status**: Early Development - Package Development Phase
> **Based on**: [NixOS AVF](https://github.com/nix-community/nixos-avf)
> **Target**: Android 15+/16+ devices with AVF support

## Overview

This project creates an Arch Linux ARM image that runs in Android's Virtualization Framework (AVF), providing a native Linux environment accessible through Android's Terminal app.

**What is AVF?**
Android Virtualization Framework is Google's virtualization platform that enables running full Linux distributions inside Android. It's used by the Terminal app (available from Android 15 QPR2 and Android 16+).

## Project Status

🏗️ **Package Development Phase**

This repository currently contains:
- ✅ Analysis of the NixOS AVF build process
- ✅ Detailed adaptation plan for Arch Linux ARM
- ✅ Project structure implementation
- ✅ PKGBUILDs for all core packages (Rust services, kernel, systemd)
- ⏳ Build testing
- ⏳ System configuration
- ⏳ Image building scripts

## Why Arch Linux ARM?

While [NixOS AVF](https://github.com/nix-community/nixos-avf) exists and works great, Arch Linux ARM offers:

- **Familiarity**: Standard Linux filesystem layout and package management
- **Simplicity**: No need to learn Nix language
- **Community**: Large Arch ARM community and package ecosystem
- **Control**: Direct access to configuration files
- **AUR**: Access to Arch User Repository packages

## Goals

1. Create a bootable Arch Linux ARM image for AVF
2. Support all AVF features (Terminal access, filesystem sharing, networking)
3. Provide easy installation and updates
4. Maintain compatibility with upstream Android AVF changes
5. Offer both minimal and full-featured images

## Documentation

- **[BUILD_ANALYSIS.md](BUILD_ANALYSIS.md)** - Detailed analysis of the NixOS build process
- **[ARCH_ADAPTATION_PLAN.md](ARCH_ADAPTATION_PLAN.md)** - Complete adaptation plan with timelines
- **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)** - Proposed project structure and guidelines

## Architecture

### Components

1. **Custom Kernel** (Linux 6.1 + AVF patches)
   - Memory balloon support
   - Virtio drivers (vsock, virtiofs, network)
   - Sound support (virtio-snd)

2. **AVF Guest Services** (Rust)
   - `forwarder_guest` - Port forwarding
   - `forwarder_guest_launcher` - Service manager with BPF
   - `shutdown_runner` - VM lifecycle management
   - `storage_balloon_agent` - Dynamic memory management

3. **Modified ttyd**
   - SSL with client certificate authentication
   - Accessibility improvements
   - Auto-login to default user

4. **System Services**
   - systemd for init
   - systemd-networkd for networking (DHCP)
   - Avahi for mDNS service discovery
   - zram for swap

### Disk Layout

```
/dev/vda1  - EFI System Partition (systemd-boot, kernel)
/dev/vda2  - Root filesystem (ext4, auto-resize)

Mounts:
/                 - Root partition
/boot             - EFI partition
/mnt/internal     - AVF internal storage (virtiofs)
/mnt/shared       - Android shared storage (virtiofs)
```

## Requirements

### Android Device
- Android 15+ with Terminal patches (e.g., GrapheneOS)
- Android 16+ Beta or later
- ARM64/AArch64 architecture
- Debuggable build (for initial installation) OR root access

### Build Environment
- Arch Linux (or similar with arch-install-scripts)
- ARM64 build capability (native or qemu-user-static)
- ~10GB free disk space
- Internet connection

## Comparison with NixOS AVF

| Feature | NixOS AVF | Arch ARM AVF |
|---------|-----------|--------------|
| Reproducible builds | ✅ Yes (Nix) | ❌ No |
| Declarative config | ✅ Yes | ⚠️ Partially |
| Easy updates | ✅ Yes | ✅ Yes (pacman) |
| Build complexity | ⚠️ High (Nix) | ✅ Low (scripts) |
| Learning curve | ⚠️ Steep | ✅ Gentle |
| Package ecosystem | ✅ Large (nixpkgs) | ✅ Large (AUR) |
| Config management | ✅ configuration.nix | ⚠️ Multiple files |

## Implementation Plan

### Phase 1: Package Development (Weeks 1-2)
- Build AVF guest services (Rust packages)
- Create custom kernel package
- Build modified ttyd

### Phase 2: System Configuration (Week 3)
- Set up systemd services
- Configure networking and boot
- Create default user setup

### Phase 3: Build Automation (Week 4)
- Write image building scripts
- Implement packaging process
- Test complete build

### Phase 4: Testing (Week 5)
- Test on real Android devices
- Verify all services work
- Document issues and fixes

### Phase 5: Release (Week 6)
- Polish documentation
- Set up CI/CD for builds
- Create initial public release

## Related Projects

- **[NixOS AVF](https://github.com/nix-community/nixos-avf)** - NixOS for AVF (inspiration for this project)
- **[Arch Linux ARM](https://archlinuxarm.org/)** - Official Arch Linux ARM project
- **[Android AVF](https://android.googlesource.com/platform/packages/modules/Virtualization/)** - Upstream AVF source

## Contributing

This project is currently in the planning phase. Contributions, suggestions, and feedback are welcome!

**How to help**:
- Review the adaptation plan and provide feedback
- Test build scripts as they're developed
- Report issues with the documentation
- Suggest improvements to the architecture

## License

To be determined (likely Apache 2.0 to match NixOS AVF and Android AVF)

## Acknowledgments

- **[NixOS AVF](https://github.com/nix-community/nixos-avf)** project for pioneering AVF Linux support
- **Google** for developing and open-sourcing AVF
- **Arch Linux ARM** team for maintaining ARM packages
- Debian AVF maintainers for the reference build scripts

## Contact

- GitHub Issues: (to be created)
- Matrix Chat: (TBD - possibly join NixOS AVF chat initially)

---

**Note**: This is a community project and is not affiliated with Google, Arch Linux, or the NixOS AVF project. Android and related marks are trademarks of Google LLC.
