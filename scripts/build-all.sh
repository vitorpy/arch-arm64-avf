#!/bin/bash
# build-all.sh
# Main orchestrator script that runs all build steps in order

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Export for sub-scripts
export PROJECT_ROOT
export BUILD_DIR="${PROJECT_ROOT}/build"
export REPO_DIR="${PROJECT_ROOT}/repo"
export SCRIPT_DIR

# Parse arguments
CLEAN_BUILD=no
SKIP_PACKAGES=no
INSTALL_DEV=no

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN_BUILD=yes
            shift
            ;;
        --skip-packages)
            SKIP_PACKAGES=yes
            shift
            ;;
        --dev)
            INSTALL_DEV=yes
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --clean           Clean build (remove existing rootfs)"
            echo "  --skip-packages   Skip building packages (use existing ones)"
            echo "  --dev             Install development packages"
            echo "  --help            Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

export CLEAN=$CLEAN_BUILD
export INSTALL_DEV

# Banner
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║        Arch Linux ARM for AVF - Build Script              ║"
echo "║                                                            ║"
echo "║  This script will build a complete Arch Linux ARM image   ║"
echo "║  for Android Virtualization Framework (AVF)               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

START_TIME=$(date +%s)

# Confirm before proceeding
if [[ "$CLEAN_BUILD" == "yes" ]]; then
    echo -e "${YELLOW}WARNING: Clean build requested. This will delete existing rootfs.${NC}"
fi

echo ""
echo "Build configuration:"
echo "  Clean build: $CLEAN_BUILD"
echo "  Skip packages: $SKIP_PACKAGES"
echo "  Dev packages: $INSTALL_DEV"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Function to run a script with error handling
run_script() {
    local script=$1
    local description=$2

    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}▶ Step: ${description}${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if bash "${script}"; then
        echo ""
        echo -e "${GREEN}✓ ${description} completed successfully${NC}"
        echo ""
    else
        echo ""
        echo -e "${RED}✗ ${description} failed!${NC}"
        echo -e "${RED}Check the output above for errors.${NC}"
        exit 1
    fi
}

# Build steps
run_script "${SCRIPT_DIR}/00-prepare-environment.sh" "Preparing Environment"

if [[ "$SKIP_PACKAGES" == "no" ]]; then
    echo -e "${YELLOW}NOTE: Package building should be done separately via GitHub Actions${NC}"
    echo -e "${YELLOW}or by manually building each PKGBUILD in pkgbuilds/ directory${NC}"
    echo ""
    read -p "Have you built the AVF packages? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Please build packages first, then re-run this script with --skip-packages${NC}"
        exit 1
    fi
fi

run_script "${SCRIPT_DIR}/10-build-rootfs.sh" "Building Root Filesystem"
run_script "${SCRIPT_DIR}/20-install-packages.sh" "Installing Packages"
run_script "${SCRIPT_DIR}/30-configure-system.sh" "Configuring System"
run_script "${SCRIPT_DIR}/40-create-disk-image.sh" "Creating Disk Image"
run_script "${SCRIPT_DIR}/50-package-image.sh" "Packaging Image"

# Calculate build time
END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))
BUILD_TIME_MIN=$((BUILD_TIME / 60))
BUILD_TIME_SEC=$((BUILD_TIME % 60))

# Success banner
echo ""
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                  🎉 BUILD SUCCESSFUL! 🎉                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo "Build completed in ${BUILD_TIME_MIN}m ${BUILD_TIME_SEC}s"
echo ""
echo "Output location:"
ls -lh "${BUILD_DIR}"/image-*.tar.gz
echo ""
echo "Next steps:"
echo "  1. Copy image to Android device:"
echo "     adb push ${BUILD_DIR}/image-*.tar.gz /sdcard/linux/images.tar.gz"
echo ""
echo "  2. Follow installation instructions in:"
echo "     ${BUILD_DIR}/README.md"
echo ""
echo "  3. Or see docs/INSTALLATION.md for detailed instructions"
echo ""
