#!/bin/bash
# 05-download-packages.sh
# Downloads built packages from GitHub Actions artifacts or local directory
# This script bridges CI builds and local image creation

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Downloading/Preparing Packages ===${NC}"

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")}"
BUILD_DIR="${BUILD_DIR:-${PROJECT_ROOT}/build}"
REPO_DIR="${REPO_DIR:-${PROJECT_ROOT}/repo}"

# Check if we're in GitHub Actions
if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "Running in GitHub Actions - packages should be in artifacts directory"
    ARTIFACTS_DIR="${GITHUB_WORKSPACE}/built-packages"

    if [[ ! -d "${ARTIFACTS_DIR}" ]]; then
        echo "ERROR: Artifacts directory not found: ${ARTIFACTS_DIR}"
        echo "Packages should be downloaded by actions/download-artifact@v4"
        exit 1
    fi

    # Create repository directory structure
    echo "Setting up package repository..."
    mkdir -p "${REPO_DIR}/aarch64"

    # Find and copy all package files
    echo "Copying packages from artifacts..."
    find "${ARTIFACTS_DIR}" -name "*.pkg.tar.*" -exec cp -v {} "${REPO_DIR}/aarch64/" \;

    # Count packages
    PKG_COUNT=$(find "${REPO_DIR}/aarch64" -name "*.pkg.tar.*" | wc -l)
    echo "Found ${PKG_COUNT} package files"

    if [[ ${PKG_COUNT} -eq 0 ]]; then
        echo -e "${YELLOW}WARNING: No packages found in artifacts!${NC}"
        exit 1
    fi

else
    echo "Running locally - checking for packages..."

    # Check if packages directory exists
    PKGBUILDS_DIR="${PROJECT_ROOT}/pkgbuilds"

    if [[ -d "${REPO_DIR}/aarch64" ]]; then
        PKG_COUNT=$(find "${REPO_DIR}/aarch64" -name "*.pkg.tar.*" 2>/dev/null | wc -l)
        if [[ ${PKG_COUNT} -gt 0 ]]; then
            echo -e "${GREEN}Using existing repository with ${PKG_COUNT} packages${NC}"
            exit 0
        fi
    fi

    echo "Searching for locally built packages..."
    mkdir -p "${REPO_DIR}/aarch64"

    # Search for packages in pkgbuilds subdirectories
    FOUND=0
    for dir in "${PKGBUILDS_DIR}"/*; do
        if [[ -d "${dir}" ]]; then
            pkg_name=$(basename "${dir}")
            pkg_file=$(find "${dir}" -maxdepth 1 -name "*.pkg.tar.*" 2>/dev/null | head -1)

            if [[ -n "${pkg_file}" ]]; then
                echo "Found: ${pkg_name}"
                cp "${pkg_file}" "${REPO_DIR}/aarch64/"
                FOUND=$((FOUND + 1))
            fi
        fi
    done

    if [[ ${FOUND} -eq 0 ]]; then
        echo -e "${YELLOW}WARNING: No locally built packages found!${NC}"
        echo ""
        echo "To build packages first, either:"
        echo "  1. Use GitHub Actions workflow (recommended)"
        echo "  2. Build manually:"
        echo "     cd pkgbuilds/avf-forwarder-guest && makepkg -s"
        echo "     (repeat for each package)"
        echo ""
        exit 1
    fi

    echo -e "${GREEN}Found ${FOUND} locally built packages${NC}"
fi

# Create repository database
echo "Creating package repository database..."
cd "${REPO_DIR}/aarch64"
repo-add aarch64.db.tar.gz *.pkg.tar.* 2>&1 | grep -v "WARNING: database file"

# List packages in repository
echo ""
echo -e "${BLUE}Package Repository Contents:${NC}"
ls -lh *.pkg.tar.* | awk '{print "  " $9 " (" $5 ")"}'

echo ""
echo -e "${GREEN}=== Package Repository Ready ===${NC}"
echo "Location: ${REPO_DIR}/aarch64"
echo "Database: aarch64.db.tar.gz"
echo ""
