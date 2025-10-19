# linux-avf Kernel Package

This package builds Linux kernel 6.1.119 with AVF (Android Virtualization Framework) patches.

## Components

### config
Kernel configuration based on Arch Linux ARM kernel with AVF-specific options enabled.

**Generated automatically** - Run `./generate-config.sh` to create/update.

### config.fragment
AVF-specific kernel options that are merged with the base Arch ARM config:
- Virtio Sound (CONFIG_SND_VIRTIO)
- Virtio drivers (balloon, vsock, fs, gpu, etc.)
- DRM as module

### arm64-balloon.patch
The AVF memory balloon patch from the Android Virtualization repository.
Enables dynamic memory management between Android host and guest VM.

Source: `avf-sources/build/debian/kernel/patches/avf/arm64-balloon.patch`

## Generating/Updating Config

To regenerate the kernel config (e.g., when Arch ARM updates their kernel):

```bash
cd pkgbuilds/linux-avf
./generate-config.sh
```

This will:
1. Fetch the latest Arch Linux ARM kernel config
2. Append AVF-specific options from `config.fragment`
3. Create the final `config` file

## Building

```bash
cd pkgbuilds/linux-avf
makepkg -s
```

### Build Time Estimates:
- Native ARM64 hardware: 30-60 minutes
- QEMU emulation (x86_64): 3-6 hours
- With ccache enabled: 50% faster on rebuilds

### Build Requirements:
- ~15GB disk space
- 4GB+ RAM recommended
- Dependencies: bc, cpio, gettext, libelf, pahole, perl, python, tar, xz

## Notes

- Kernel version pinned to 6.1.119 (matches AVF upstream)
- Config based on Arch Linux ARM for maximum compatibility
- AVF patches from android-16.0.0_r2 tag
