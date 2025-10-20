# Building Arch Linux ARM for AVF

This guide explains how to build the Arch Linux ARM image for Android Virtualization Framework (AVF).

## Prerequisites

### Build System Requirements

- **Operating System**: Arch Linux (recommended) or any Linux with arch-install-scripts
- **Architecture**: x86_64 with QEMU support OR native ARM64
- **Disk Space**: At least 15GB free
- **RAM**: 4GB minimum, 8GB recommended
- **Time**: 30-60 minutes for full build (depending on hardware)

### Required Packages

On Arch Linux:
```bash
sudo pacman -S base-devel arch-install-scripts git wget \
               parted dosfstools e2fsprogs pigz systemd \
               qemu-user-static-binfmt
```

On other distributions, you'll need equivalent packages for:
- `arch-install-scripts` (pacstrap, arch-chroot)
- Partitioning tools (parted, gdisk)
- Filesystem tools (mkfs.vfat, mkfs.ext4, tune2fs)
- Compression (pigz)
- QEMU user-mode emulation (if building on x86_64)

## Build Process Overview

The build process consists of several steps:

1. **Prepare Environment** - Verify dependencies and create directories
2. **Build Rootfs** - Bootstrap Arch Linux ARM base system
3. **Install Packages** - Install essential and AVF packages
4. **Configure System** - Apply configurations and enable services
5. **Create Disk Image** - Create GPT partitioned disk with bootloader
6. **Package Image** - Extract partitions and create AVF-compatible tarball

## Building Packages

### Option 1: GitHub Actions (Recommended)

The easiest way is to let GitHub Actions build the packages:

1. Fork or push to your repository
2. GitHub Actions will automatically build all packages
3. Download artifacts from the Actions tab
4. Place `.pkg.tar.zst` files in `repo/aarch64/`

### Option 2: Build Locally

Build each package manually:

```bash
cd pkgbuilds/avf-forwarder-guest
makepkg -s

cd ../avf-forwarder-guest-launcher
makepkg -s

# Repeat for all packages...
```

Note: Kernel building takes the longest (30-120 minutes depending on hardware).

### Option 3: Use Pre-built Packages

Download pre-built packages from the project releases page and place them in `repo/aarch64/`.

## Building the Image

### Quick Build

```bash
cd scripts
./build-all.sh
```

The script will:
- Check dependencies
- Ask for confirmation
- Run all build steps in order
- Create the final image tarball in `build/`

### Build Options

```bash
# Clean build (removes existing rootfs)
./build-all.sh --clean

# Skip package building step
./build-all.sh --skip-packages

# Include development packages
./build-all.sh --dev

# Combine options
./build-all.sh --clean --dev
```

### Step-by-Step Build

Run each script manually for more control:

```bash
# 1. Prepare environment
./00-prepare-environment.sh

# 2. Build rootfs
./10-build-rootfs.sh

# 3. Install packages
./20-install-packages.sh

# 4. Configure system
./30-configure-system.sh

# 5. Create disk image
./40-create-disk-image.sh

# 6. Package for AVF
./50-package-image.sh
```

## Build Output

After successful build:

```
build/
├── image-archarm-avf-YYYYMMDD-HHMMSS-aarch64.tar.gz
├── image-archarm-avf-YYYYMMDD-HHMMSS-aarch64.tar.gz.sha256
├── disk.img
├── efi_part
├── root_part
├── vm_config.json
├── build_id
├── efi_guid
├── root_guid
└── README.md
```

The main output is `image-*.tar.gz` - this is what you install on Android.

## Build Environment Variables

You can customize the build with environment variables:

```bash
# Clean existing rootfs before building
export CLEAN=yes

# Install development packages
export INSTALL_DEV=yes

# Custom build directory
export BUILD_DIR=/path/to/build

# Custom repository location
export REPO_DIR=/path/to/repo
```

## Cross-Architecture Building

### Building on x86_64 for ARM64

The scripts automatically detect architecture and use QEMU user-mode emulation if available.

Ensure `qemu-user-static-binfmt` is installed and enabled:

```bash
sudo pacman -S qemu-user-static-binfmt
sudo systemctl restart systemd-binfmt.service
```

Verify ARM64 support:
```bash
cat /proc/sys/fs/binfmt_misc/qemu-aarch64
```

### Building on Native ARM64

Building on ARM64 hardware (Raspberry Pi, ARM server, etc.) is faster and doesn't require QEMU.

The scripts automatically detect native ARM64 and skip QEMU setup.

## Troubleshooting

### "Missing required commands"

Install the missing packages listed in the error. On Arch Linux:
```bash
sudo pacman -S <missing-package>
```

### "Insufficient disk space"

Free up at least 15GB:
```bash
# Clean package cache
sudo pacman -Scc

# Remove build directory
rm -rf build/
```

### "QEMU binfmt not detected"

Install and enable QEMU user-mode emulation:
```bash
sudo pacman -S qemu-user-static-binfmt
sudo systemctl restart systemd-binfmt.service
```

### "Rootfs already exists"

To rebuild from scratch:
```bash
./build-all.sh --clean
```

Or manually:
```bash
sudo rm -rf build/rootfs
./10-build-rootfs.sh
```

### Build fails during package installation

Ensure AVF packages are built and present in `repo/aarch64/`:
```bash
ls -l repo/aarch64/*.pkg.tar.zst
```

### "bootctl install failed"

This is expected in cross-architecture builds. The script falls back to manual bootloader installation, which works correctly.

## Advanced Customization

### Custom Kernel Configuration

Edit `pkgbuilds/linux-avf/config` before building the kernel package.

### Additional System Packages

Edit the `ESSENTIAL_PKGS` array in `scripts/20-install-packages.sh`.

### Custom System Configuration

Modify files in `configs/` and `systemd/` directories before running the build.

### Image Size

Adjust `DISK_SIZE_MB` in `scripts/40-create-disk-image.sh`:
```bash
DISK_SIZE_MB=8192  # Default 8GB
DISK_SIZE_MB=16384 # For 16GB image
```

## Build Performance Tips

1. **Use Native ARM64**: Building on ARM64 hardware is significantly faster
2. **SSD Storage**: Use SSD for build directory
3. **Parallel Builds**: The scripts use all available CPU cores automatically
4. **Cached Downloads**: Arch ARM tarball is cached after first download
5. **Skip Clean**: Only use `--clean` when necessary

## CI/CD Integration

The project includes GitHub Actions workflows for automated builds:

- `.github/workflows/build-packages.yml` - Builds all PKGBUILD packages
- Runs on GitHub's ARM64 runners (free for public repos)
- Artifacts are uploaded and can be downloaded

To set up CI/CD for image building, create a workflow that:
1. Builds packages
2. Runs `build-all.sh --skip-packages`
3. Uploads the final tarball as a release artifact

## Next Steps

After building the image:

1. Verify the tarball was created:
   ```bash
   ls -lh build/image-*.tar.gz
   ```

2. Check the SHA256 checksum:
   ```bash
   cat build/image-*.tar.gz.sha256
   ```

3. Follow [INSTALLATION.md](INSTALLATION.md) to install on your Android device

## Getting Help

- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
- Open an issue on GitHub with build logs
- Include output of `./00-prepare-environment.sh`
