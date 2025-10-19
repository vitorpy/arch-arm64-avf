# Project Structure for arch-arm64-avf

This document outlines the recommended directory structure for the Arch Linux ARM AVF project.

## Proposed Directory Layout

```
arch-arm64-avf/
├── README.md                           # Main project documentation
├── BUILD_ANALYSIS.md                   # Analysis of NixOS build (this reference)
├── ARCH_ADAPTATION_PLAN.md            # Detailed adaptation plan
├── PROJECT_STRUCTURE.md               # This file
│
├── pkgbuilds/                         # PKGBUILD files for all packages
│   ├── avf-forwarder-guest/
│   │   └── PKGBUILD
│   ├── avf-forwarder-guest-launcher/
│   │   ├── PKGBUILD
│   │   └── guest-tcpstates.patch
│   ├── avf-shutdown-runner/
│   │   └── PKGBUILD
│   ├── avf-storage-balloon-agent/
│   │   └── PKGBUILD
│   ├── avf-ttyd/
│   │   ├── PKGBUILD
│   │   ├── client_cert.patch
│   │   └── xtermjs_a11y.patch
│   ├── linux-avf/
│   │   ├── PKGBUILD
│   │   ├── config
│   │   ├── arm64-balloon.patch
│   │   └── linux.preset
│   └── systemd-avf/                   # Optional: if patching systemd
│       ├── PKGBUILD
│       └── systemd-esp-type-ignore.patch
│
├── configs/                           # System configuration files
│   ├── fstab
│   ├── locale.conf
│   ├── vconsole.conf
│   ├── hostname
│   ├── avahi/
│   │   └── avahi-daemon.conf
│   ├── systemd-networkd/
│   │   └── 80-dhcp.network
│   ├── systemd-boot/
│   │   ├── loader.conf
│   │   └── entries/
│   │       └── arch.conf
│   ├── sudoers.d/
│   │   └── 10-wheel-nopasswd
│   ├── sysctl.d/
│   │   └── 99-avf.conf
│   ├── zram-generator.conf
│   └── vm_config.json.template
│
├── systemd/                           # Systemd service files
│   ├── ttyd-avf.service
│   ├── avf-forwarder-guest-launcher.service
│   ├── avf-shutdown-runner.service
│   ├── avf-storage-balloon-agent.service
│   └── avahi-ttyd.service
│
├── scripts/                           # Build and utility scripts
│   ├── build-all.sh                   # Main build orchestrator
│   ├── 00-prepare-environment.sh      # Verify deps, create dirs
│   ├── 10-build-packages.sh           # Build all PKGBUILDs
│   ├── 20-build-rootfs.sh             # Bootstrap Arch ARM
│   ├── 30-install-packages.sh         # Install AVF packages
│   ├── 40-configure-system.sh         # Apply configs, create user
│   ├── 50-create-disk-image.sh        # Create and partition disk
│   ├── 60-package-image.sh            # Create final tarball
│   ├── utils/
│   │   ├── fetch-avf-sources.sh       # Download AVF repository
│   │   ├── build-repo.sh              # Create pacman repository
│   │   └── extract-kernel-config.sh   # Extract config from NixOS
│   └── android/                       # Android deployment scripts
│       ├── install-image.sh           # Install to device
│       └── clean-vm.sh                # Clean existing VM
│
├── patches/                           # Collected patches from AVF
│   ├── kernel/
│   │   └── arm64-balloon.patch
│   ├── systemd/
│   │   └── systemd-esp-type-ignore.patch
│   ├── ttyd/
│   │   ├── client_cert.patch
│   │   └── xtermjs_a11y.patch
│   └── guest/
│       └── guest-tcpstates.patch
│
├── repo/                              # Local package repository (generated)
│   ├── aarch64/
│   │   ├── *.pkg.tar.zst
│   │   └── aarch64.db.tar.gz
│   └── .gitignore                     # Ignore generated packages
│
├── build/                             # Build artifacts (generated)
│   ├── rootfs/                        # Temporary rootfs
│   ├── disk.img                       # Raw disk image
│   ├── efi_part                       # Extracted EFI partition
│   ├── root_part                      # Extracted root partition
│   ├── vm_config.json                 # Generated VM config
│   ├── build_id                       # Build identifier
│   └── .gitignore                     # Ignore build artifacts
│
├── docs/                              # Additional documentation
│   ├── BUILDING.md                    # How to build the image
│   ├── INSTALLATION.md                # How to install on device
│   ├── TROUBLESHOOTING.md             # Common issues and solutions
│   └── DEVELOPMENT.md                 # Development guidelines
│
├── .github/                           # GitHub specific files
│   ├── workflows/
│   │   ├── build-image.yml            # CI to build image
│   │   └── build-packages.yml         # CI to build packages
│   └── ISSUE_TEMPLATE/
│       ├── bug_report.md
│       └── feature_request.md
│
├── .gitignore                         # Git ignore file
├── .editorconfig                      # Editor configuration
└── LICENSE                            # License file (Apache 2.0?)
```

## Directory Descriptions

### `/pkgbuilds/`
Contains PKGBUILD files for all custom packages. Each subdirectory represents one package with its PKGBUILD and any necessary patches or additional files.

**Guidelines**:
- Follow Arch packaging guidelines
- Include complete .SRCINFO for each package
- Document any deviations from standard builds
- Keep patches in same directory as PKGBUILD

### `/configs/`
System configuration files that will be copied to the rootfs during build. These are static configurations that define how the system behaves.

**Guidelines**:
- Use comments to document non-obvious settings
- Keep minimal - only include what differs from defaults
- Separate by subsystem (networkd, boot, etc.)

### `/systemd/`
Systemd unit files for AVF-specific services. These are installed to `/etc/systemd/system/` in the image.

**Guidelines**:
- Follow systemd unit file best practices
- Document dependencies and ordering
- Include [Install] sections for enabling

### `/scripts/`
Build automation scripts. Numbered scripts run in order, utility scripts are called as needed.

**Guidelines**:
- Use bash with set -euo pipefail
- Document each script's purpose at the top
- Make scripts idempotent where possible
- Include error checking and helpful messages

### `/patches/`
Collection of all patches, organized by component. These are referenced by PKGBUILDs.

**Guidelines**:
- Include source/origin in patch file header
- Group by component
- Use descriptive filenames

### `/repo/` (generated)
Local pacman repository created during build. Contains built packages.

**Guidelines**:
- Don't commit to git (use .gitignore)
- Regenerate for each build
- Can be published for distribution

### `/build/` (generated)
Temporary build artifacts and final output.

**Guidelines**:
- Don't commit to git
- Clean between builds
- Final image is the tarball in this directory

### `/docs/`
User and developer documentation.

**Guidelines**:
- Write for different audiences (users vs developers)
- Include screenshots/examples where helpful
- Keep up to date with code changes

## File Naming Conventions

### PKGBUILD packages:
- Prefix with `avf-` for AVF-specific packages
- Example: `avf-forwarder-guest`, `linux-avf`

### Systemd services:
- Use descriptive names matching binary names
- Suffix with `.service`
- Example: `avf-forwarder-guest-launcher.service`

### Scripts:
- Number main build scripts: `00-`, `10-`, `20-`, etc.
- Use descriptive names with hyphens
- Use `.sh` extension

### Config files:
- Match their destination filename when possible
- Group in subdirectories by destination

## Build Output

The final build produces:

```
build/image-<version>-aarch64.tar.gz
```

Contents:
```
build_id              # Build identifier
efi_part              # EFI partition image
root_part             # Root filesystem image
vm_config.json        # VM configuration
README.md             # Installation instructions
```

## Getting Started

1. Clone repository:
   ```bash
   git clone https://github.com/your-org/arch-arm64-avf.git
   cd arch-arm64-avf
   ```

2. Install build dependencies:
   ```bash
   sudo pacman -S base-devel arch-install-scripts parted dosfstools e2fsprogs pigz git
   ```

3. Run build:
   ```bash
   ./scripts/build-all.sh
   ```

4. Output will be in `build/image-<version>-aarch64.tar.gz`

## Version Control

### What to commit:
- All source files (PKGBUILDs, scripts, configs)
- Documentation
- Patches
- .gitignore files

### What NOT to commit:
- Built packages (`repo/`)
- Build artifacts (`build/`)
- Downloaded sources (AVF repository)
- Temporary files

### .gitignore should include:
```
repo/aarch64/*.pkg.tar.zst
repo/aarch64/*.db*
build/
*.log
src/
pkg/
avf-sources/
```

## Development Workflow

1. **Make changes** to PKGBUILDs or scripts
2. **Test locally** with `./scripts/build-all.sh`
3. **Verify image** on Android device
4. **Commit changes** with descriptive message
5. **Push to GitHub** - CI builds automatically
6. **Create release** when stable

## CI/CD Integration

GitHub Actions should:
- Build all packages on commit to main
- Create package repository
- Build full image
- Upload artifacts
- Create GitHub release for tags

## Maintenance

### Regular tasks:
- Update AVF sources when new Android releases
- Update Arch packages to latest versions
- Test on new Android versions
- Update documentation
- Respond to issues

### When to update:
- New Android release with AVF changes
- Security updates to kernel or packages
- Bug fixes from upstream
- Feature requests from users
