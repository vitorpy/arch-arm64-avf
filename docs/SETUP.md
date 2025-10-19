# Setup Guide

## Initial Repository Setup

After cloning this repository, you need to initialize the AVF sources submodule:

```bash
git submodule update --init --recursive
cd avf-sources
git checkout android-16.0.0_r2
cd ..
```

## Extract Patches

Once the submodule is initialized, extract the patches from the AVF sources:

```bash
./scripts/utils/extract-patches.sh
```

This will copy the following patches:
- `arm64-balloon.patch` - Kernel memory balloon support
- `client_cert.patch` - ttyd client certificate auth
- `xtermjs_a11y.patch` - ttyd accessibility improvements

## Build Environment Setup

### On Arch Linux ARM (Native Build)

```bash
# Install build dependencies
sudo pacman -S base-devel git rust cargo protobuf

# For kernel building
sudo pacman -S bc cpio gettext libelf pahole perl python tar xz

# For systemd building
sudo pacman -S meson python-jinja python-lxml libcap audit openssl
```

### On x86_64 with QEMU (Cross-Platform Build)

```bash
# Install QEMU user mode emulation
sudo pacman -S qemu-user-static qemu-user-static-binfmt

# Verify binfmt_misc is configured
ls /proc/sys/fs/binfmt_misc/qemu-aarch64

# Now you can build ARM64 packages on x86_64
```

### On Dedicated Build Server

If you have access to arm-builder.vitorpy.com (46.62.209.174):

```bash
# SSH into the build server
ssh user@arm-builder.vitorpy.com

# Clone repository
git clone https://github.com/yourusername/arch-arm64-avf.git
cd arch-arm64-avf
git submodule update --init
./scripts/utils/extract-patches.sh
```

## Building Packages

### Build Individual Package

```bash
cd pkgbuilds/avf-forwarder-guest
makepkg -s
```

### Build All Packages

```bash
# TODO: Create build-all script
./scripts/build-packages.sh
```

## Creating Local Package Repository

```bash
# Create repository directory
mkdir -p repo/aarch64

# Copy built packages
cp pkgbuilds/*/avf-*.pkg.tar.zst repo/aarch64/
cp pkgbuilds/*/linux-avf-*.pkg.tar.zst repo/aarch64/
cp pkgbuilds/*/systemd-avf-*.pkg.tar.zst repo/aarch64/

# Generate repository database
cd repo/aarch64
repo-add aarch64.db.tar.gz *.pkg.tar.zst
cd ../..
```

## Troubleshooting

### Submodule Clone Fails

If the AVF sources submodule fails to clone:

```bash
# Remove and try again
rm -rf avf-sources .git/modules/avf-sources
git submodule add https://android.googlesource.com/platform/packages/modules/Virtualization avf-sources
git submodule update --init
cd avf-sources && git checkout android-16.0.0_r2
```

### Build Fails with Missing Dependencies

Make sure you have all makedepends installed:

```bash
cd pkgbuilds/<package-name>
makepkg --syncdeps  # Automatically install dependencies
```

### QEMU Builds are Slow

This is normal. ARM64 emulation on x86_64 can be 5-10x slower than native builds. Consider:
- Using a native ARM64 builder
- Building overnight
- Using distcc with ARM64 workers

## Next Steps

After setting up the build environment:
1. Build all packages
2. Create local package repository
3. Proceed to image building (see docs/BUILDING.md)
