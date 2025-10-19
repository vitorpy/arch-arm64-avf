# Planning Summary: Arch Linux ARM AVF Project

## Executive Summary

This document summarizes the analysis of the NixOS AVF build process and outlines key decisions needed to proceed with the Arch Linux ARM adaptation.

## What We Learned from NixOS AVF

### Core Build Process
1. **Source Management**: Fetches Android's AVF repository (android-16.0.0_r2) containing:
   - Rust-based guest services (4 binaries)
   - Kernel patches for ARM64 memory balloon
   - ttyd patches for SSL and accessibility

2. **Package Building**: Compiles several components:
   - 4 Rust services for VM management
   - Modified ttyd with client certificate support
   - Linux 6.1 kernel with AVF patches
   - (Optional) Patched systemd to accept non-standard EFI partition GUIDs

3. **Image Creation**: Builds a specialized disk image:
   - GPT partition table with EFI + root partitions
   - Extracts partitions as separate binary files
   - Generates VM configuration (vm_config.json)
   - Packages everything as tarball for AVF consumption

4. **System Configuration**: Sets up the guest OS with:
   - systemd-boot bootloader (0 second timeout)
   - systemd-networkd for DHCP networking
   - Avahi for mDNS service discovery
   - virtiofs mounts for Android filesystem sharing
   - Auto-login default user with passwordless sudo

### Key Technical Insights

**Filesystem Compatibility Issue**:
- Android's e2fsck doesn't support `orphan_file` ext4 feature
- Must run `tune2fs -O ^orphan_file` on root partition
- This is critical - image won't boot without it

**Partition GUID Issue**:
- AVF uses custom partition GUIDs, not standard EFI GUID (C12A7328-F81F-11D2-BA4B-00A0C93EC93B)
- systemd-boot validates partition type and rejects non-standard GUIDs
- Must either patch systemd OR modify partition type temporarily
- NixOS patches systemd - probably best approach

**Memory Management**:
- VM allocated 4096MB but actual usage limited by phone RAM
- OOM killer on phone will crash VM if it uses too much
- Balloon agent allows Android to reclaim guest memory
- zram/swap recommended for better memory utilization

**Service Communication**:
- All AVF services use gRPC
- Port file location: `/mnt/internal/debian_service_port`
- Services must wait for `/mnt/internal` mount
- SSL certificates also come from `/mnt/internal`

## Critical Decisions Needed

### Decision 1: Build Environment Strategy

**Question**: How should we handle ARM64 builds?

**Options**:

A. **Native ARM64 builder** (Raspberry Pi 4/5, ARM server, etc.)
   - ✅ Pros: Fast, native compilation, no emulation overhead
   - ❌ Cons: Requires ARM64 hardware

B. **QEMU user-mode emulation** (x86_64 host with qemu-user-static)
   - ✅ Pros: Can build on any x86_64 machine
   - ❌ Cons: Slower (~10x), can be flaky for complex builds

C. **Cross-compilation** (x86_64 host, cross-compile to ARM64)
   - ✅ Pros: Fast builds
   - ❌ Cons: Complex setup, not all packages support cross-compilation

D. **Hybrid approach** (cross-compile where possible, qemu for the rest)
   - ✅ Pros: Best of both worlds
   - ❌ Cons: Most complex setup

**Recommendation**: Start with B (QEMU) for development, add A (native) for CI/releases if needed.

---

### Decision 2: Systemd Partition Validation

**Question**: How to handle systemd-boot's EFI partition type validation?

**Options**:

A. **Patch systemd** (like NixOS does)
   - ✅ Pros: Clean solution, matches upstream NixOS AVF
   - ❌ Cons: Custom package to maintain, breaks on systemd updates

B. **Hook to modify partition type** (change GUID before/after operations)
   - ✅ Pros: No systemd patch needed
   - ❌ Cons: Fragile, might break in edge cases

C. **Use GRUB instead** (different bootloader)
   - ✅ Pros: No partition type issues
   - ❌ Cons: Slower boot, diverges from AVF reference implementation

D. **Wait for systemd fix** (report issue upstream)
   - ✅ Pros: Clean long-term solution
   - ❌ Cons: May never happen, blocks project

**Recommendation**: A (patch systemd). It's proven to work in NixOS AVF.

---

### Decision 3: Package Distribution

**Question**: How should users get the AVF packages?

**Options**:

A. **Custom binary repository** (pacman repo hosted on GitHub/server)
   - ✅ Pros: Easy installation, pre-built binaries
   - ❌ Cons: Need to host repository, manage signatures

B. **AUR packages** (users build from source)
   - ✅ Pros: Official Arch distribution method, community maintained
   - ❌ Cons: Users must compile (slow on phone if rebuilding), ARM64 compilation needed

C. **GitHub Releases** (direct .pkg.tar.zst downloads)
   - ✅ Pros: Simple, no repo infrastructure needed
   - ❌ Cons: Manual installation, no automatic updates

D. **Hybrid** (GitHub releases + optional custom repo)
   - ✅ Pros: Flexibility for users
   - ❌ Cons: Multiple distribution paths to maintain

**Recommendation**: D (Hybrid). Release .pkg.tar.zst files on GitHub, provide optional repo setup for convenience.

---

### Decision 4: Initial Image vs Upgrade Path

**Question**: What's the relationship between initial image and subsequent updates?

**Approaches**:

A. **Immutable initial + pacman updates** (like NixOS AVF)
   - Initial image: Minimal bootable system with pacman configured
   - Updates: User runs `pacman -Syu` inside VM
   - ✅ Pros: Small initial image, flexible updates
   - ❌ Cons: Must get package repo working correctly

B. **Full image only** (no in-VM updates)
   - Ship complete system in initial image
   - Updates require re-flashing entire image
   - ✅ Pros: Simpler, guaranteed consistent state
   - ❌ Cons: Large downloads, lose user data (unless backup/restore)

C. **Layered approach** (base image + optional packages)
   - Ship minimal base image
   - Provide package groups for common use cases
   - ✅ Pros: Flexible, user choice
   - ❌ Cons: More complex documentation

**Recommendation**: A (Immutable initial + pacman). Matches NixOS AVF approach and provides best UX.

---

### Decision 5: Kernel Strategy

**Question**: How to handle the custom kernel?

**Options**:

A. **Custom kernel package** (linux-avf)
   - Full kernel package with AVF patches
   - ✅ Pros: Full control, all features working
   - ❌ Cons: Large package, slow to build, must track kernel updates

B. **Kernel patch package** (patches for linux-aarch64)
   - Provide patches that users apply to standard kernel
   - ✅ Pros: Smaller, leverages official kernel
   - ❌ Cons: Requires users to rebuild kernel

C. **DKMS modules** (load AVF features as modules)
   - Keep stock kernel, add AVF as modules
   - ✅ Pros: Minimal changes to base system
   - ❌ Cons: Limited - may not work for all AVF features

**Recommendation**: A (custom kernel). The kernel modifications are substantial (balloon patch) and need to be baked in.

---

### Decision 6: Development Workflow

**Question**: Where should development happen first?

**Options**:

A. **Build packages first** (bottom-up)
   - Create all PKGBUILDs
   - Test each package individually
   - Then assemble into image
   - ✅ Pros: Incremental progress, easier debugging
   - ❌ Cons: Can't test full system until end

B. **Build image script first** (top-down)
   - Create image building script using existing Arch packages
   - Replace with custom packages incrementally
   - ✅ Pros: Working system quickly, validates approach
   - ❌ Cons: May need to refactor later

C. **Parallel development** (both at once)
   - Some devs on packages, some on image scripts
   - ✅ Pros: Faster overall
   - ❌ Cons: Requires coordination, potential conflicts

**Recommendation**: A (bottom-up). Build packages first to ensure they work, then assembly is straightforward.

---

## Proposed Work Plan

Based on the decisions above, here's a suggested approach:

### Phase 0: Setup (Week 1)
- [ ] Set up build environment (QEMU user-mode on x86_64 host)
- [ ] Create GitHub repository
- [ ] Set up project structure (directories, .gitignore, etc.)
- [ ] Fetch AVF sources and extract patches

### Phase 1: Package Development (Weeks 2-3)
- [ ] Create PKGBUILD for linux-avf
- [ ] Create PKGBUILDs for 4 Rust services
- [ ] Create PKGBUILD for avf-ttyd
- [ ] Create PKGBUILD for systemd-avf (patched)
- [ ] Build and test each package individually
- [ ] Create local pacman repository

### Phase 2: Configuration Files (Week 4)
- [ ] Create systemd service files
- [ ] Create systemd-networkd config
- [ ] Create systemd-boot config
- [ ] Create fstab and other system configs
- [ ] Create vm_config.json template

### Phase 3: Build Scripts (Week 5)
- [ ] Write rootfs creation script
- [ ] Write package installation script
- [ ] Write system configuration script
- [ ] Write disk image creation script
- [ ] Write final packaging script
- [ ] Test complete build pipeline

### Phase 4: Testing & Debugging (Week 6)
- [ ] Test image on Android 16 device
- [ ] Debug boot issues
- [ ] Verify all services start
- [ ] Test network connectivity
- [ ] Test filesystem sharing
- [ ] Test ttyd connection

### Phase 5: Documentation & Release (Week 7)
- [ ] Write installation guide
- [ ] Write build guide
- [ ] Write troubleshooting guide
- [ ] Set up CI/CD (GitHub Actions)
- [ ] Create initial release

## Resource Requirements

### Hardware:
- Build machine: x86_64 Linux with 16GB RAM, 50GB disk space
- Test device: Android phone with AVF support (Pixel 6+ recommended)

### Software:
- Arch Linux or similar (for pacstrap)
- qemu-user-static and binfmt_misc
- Standard build tools (base-devel)
- Git, wget, pigz

### Time Estimate:
- Solo developer: ~7 weeks part-time (~70 hours)
- With 2-3 contributors: ~4 weeks
- With NixOS AVF maintainer guidance: ~3 weeks

## Risk Assessment

### High Risk:
1. **Kernel compatibility** - AVF patches may not apply cleanly to newer kernels
   - Mitigation: Pin to specific kernel version initially

2. **Partition GUID handling** - Systemd patch may be insufficient
   - Mitigation: Have fallback plan (GRUB or partition type switching)

### Medium Risk:
1. **Rust service compilation** - Cross-compilation issues
   - Mitigation: Use QEMU if cross-compile fails

2. **Memory constraints** - Build may fail on low-memory devices
   - Mitigation: Document minimum requirements, use swap

### Low Risk:
1. **Packaging issues** - PKGBUILD errors
   - Mitigation: Follow Arch guidelines, test thoroughly

2. **Documentation gaps** - Missing important details
   - Mitigation: Get feedback from NixOS AVF users

## Questions for Discussion

Before starting implementation:

1. **Target audience**: Who is this for? (Developers, power users, general users?)
2. **Support commitment**: How long will we maintain this? (1 year, ongoing?)
3. **Collaboration**: Should we coordinate with NixOS AVF maintainers?
4. **Licensing**: What license? (Apache 2.0 like NixOS AVF?)
5. **Testing**: What devices can we test on? (Need Android 16 beta access?)
6. **Distribution**: GitHub only or also Matrix/Discord community?

## Next Actions

1. **Review this plan** - Does it make sense? Anything missing?
2. **Make key decisions** - Decide on the 6 critical questions above
3. **Set up repository** - Create GitHub repo with initial structure
4. **Begin Phase 0** - Set up build environment
5. **Start development** - Begin with Phase 1 (packages)

## Success Criteria

We'll know this project is successful when:

- ✅ Users can download a pre-built image and install it on their Android device
- ✅ The image boots and is accessible via Terminal app
- ✅ All AVF features work (networking, file sharing, services)
- ✅ Users can update packages using pacman
- ✅ Documentation is clear enough for non-experts
- ✅ CI builds images automatically on each release
- ✅ Community adopts and contributes to the project

---

**Ready to discuss and plan the work together!**
