# linux-avf Kernel Package

This package builds Linux kernel 6.1.119 with AVF (Android Virtualization Framework) patches.

## Required Files

### config
The kernel configuration file. This should be based on a standard ARM64 config with the following AVF-specific options enabled:

```
CONFIG_SND_VIRTIO=m
CONFIG_SND=y
CONFIG_SOUND=y
CONFIG_VHOST_VSOCK=m
CONFIG_VIRTIO_BALLOON=y
CONFIG_VIRTIO_BLK=y
CONFIG_VIRTIO_CONSOLE=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_PCI=y
CONFIG_VIRTIOFS=y
CONFIG_DRM_VIRTIO_GPU=y
```

### arm64-balloon.patch
The AVF memory balloon patch from the Android Virtualization repository.

Located at: `avf-sources/build/debian/kernel/patches/avf/arm64-balloon.patch`

## How to Generate the Config

Option 1: Extract from running system
```bash
zcat /proc/config.gz > config
```

Option 2: Use defconfig as base
```bash
# On ARM64 system
make defconfig
# Then manually enable required options
make menuconfig
```

Option 3: Use Arch Linux ARM kernel config
```bash
# Download from https://github.com/archlinuxarm/PKGBUILDs
# tree/master/core/linux-aarch64
```

## Building

```bash
cd pkgbuilds/linux-avf
makepkg -s
```

Note: This is a large build and may take 30-60 minutes on ARM64 hardware, or several hours under QEMU emulation.
