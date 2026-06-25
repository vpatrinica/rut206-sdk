#!/usr/bin/env bash

# Easy build wrapper for RutOS SDK using Docker and parallel compilation.
# Bundles Tailscale and its VuCI WebUI application.

set -e

# Terminate on error and print trace if debug enabled
[[ "$DEBUG" == "1" ]] && set -x

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0;0m'

log_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

log_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

log_warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

log_err() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

SDK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REF_SDK_DIR="/home/duser/prj/task/RUTM_R_GPL_00.07.20.3"
TARGET_PROFILE_SYMBOL="CONFIG_TARGET_ramips_mt76x8_DEVICE_TEMPLATE_teltonika_rut206"
TARGET_PROFILE_VALUE="DEVICE_TEMPLATE_teltonika_rut206"
TARGET_INCLUDED_DEVICES="TEMPLATE_teltonika_rut206"
TARGET_DEVICE_DTS="mt7628an-teltonika-rut206"
TAILSCALE_PKG_MODE="${TAILSCALE_PKG_MODE:-m}"
TAILSCALE_API_PKG_MODE="${TAILSCALE_API_PKG_MODE:-m}"
TAILSCALE_UI_PKG_MODE="${TAILSCALE_UI_PKG_MODE:-m}"

set_package_mode() {
    local pkg="$1"
    local mode="$2"

    case "$mode" in
        y|m)
            echo "CONFIG_PACKAGE_${pkg}=${mode}" >> .config
            ;;
        *)
            echo "# CONFIG_PACKAGE_${pkg} is not set" >> .config
            ;;
    esac
}


# 2. Update and Install Feeds
update_feeds() {
    log_info "Updating package feeds inside Docker..."
    ./scripts/dockerbuild ./scripts/feeds update -a
    log_info "Installing package feeds inside Docker..."
    ./scripts/dockerbuild ./scripts/feeds install -a
    log_info "Uninstalling conflicting ffmpeg package from feeds..."
    ./scripts/dockerbuild ./scripts/feeds uninstall ffmpeg
    log_success "Feeds updated and installed."
}

# 3. Configure Tailscale and its VuCI applications in .config
configure_tailscale() {
    log_info "Configuring Tailscale packages in .config..."
    if [ ! -f .config ]; then
        log_warn ".config not found. Running default configuration first..."
        ./scripts/dockerbuild make defconfig
    fi

    # Force single-device image generation for RUT206.
    sed -i '/CONFIG_TARGET_ramips_mt76x8_DEVICE_TEMPLATE_teltonika_/d' .config
    sed -i '/CONFIG_TARGET_ramips_mt76x8_DEVICE_teltonika_rute/d' .config
    sed -i '/CONFIG_TARGET_PROFILE=/d' .config
    sed -i '/CONFIG_INCLUDED_DEVICES=/d' .config

    # Remove existing definitions to avoid duplicates/conflicts.
    # Keep this list aligned with the package selections below so reruns stay idempotent.
    sed -i '/CONFIG_PACKAGE_tailscale/d' .config
    sed -i '/CONFIG_PACKAGE_vuci-app-tailscale-api/d' .config
    sed -i '/CONFIG_PACKAGE_vuci-app-tailscale-ui/d' .config
    sed -i '/CONFIG_PACKAGE_gpsctl/d' .config
    sed -i '/CONFIG_PACKAGE_libgps/d' .config
    sed -i '/CONFIG_PACKAGE_gpsd[^-]/d' .config
    sed -i '/CONFIG_PACKAGE_strongswan$/d' .config
    sed -i '/CONFIG_PACKAGE_strongswan-minimal/d' .config
    sed -i '/CONFIG_PACKAGE_grpcurl/d' .config

    # Build only RUT206 to avoid multi-DTB FIT images that exceed flash limits.
    echo "${TARGET_PROFILE_SYMBOL}=y" >> .config
    echo "CONFIG_TARGET_PROFILE=\"${TARGET_PROFILE_VALUE}\"" >> .config
    echo "CONFIG_INCLUDED_DEVICES=\"${TARGET_INCLUDED_DEVICES}\"" >> .config

    # Keep tailscale available, but default VuCI app packages to modules to fit
    # the 32MB flash budget for rut206 images.
    set_package_mode "tailscale" "${TAILSCALE_PKG_MODE}"
    #set_package_mode "vuci-app-tailscale-api" "${TAILSCALE_API_PKG_MODE}"
    #set_package_mode "vuci-app-tailscale-ui" "${TAILSCALE_UI_PKG_MODE}"

    # Do not force extra rootfs packages here. The Tailscale packages only depend on
    # tailscaled internally, and adding unrelated packages pushes the firmware over
    # the image size limit on teltonika_rute.

    # Keep grpcurl out of the rootfs; it is a large debug tool and not needed for Tailscale.
    #echo "# CONFIG_PACKAGE_grpcurl is not set" >> .config
    #echo "# CONFIG_PACKAGE_gpsctl is not set" >> .config
    #echo "# CONFIG_PACKAGE_strongswan is not set" >> .config
    #echo "# CONFIG_PACKAGE_strongswan-minimal is not set" >> .config

    log_info "Resolving configuration dependencies (make defconfig)..."
    ./scripts/dockerbuild make defconfig
    log_info "Target profile forced to ${TARGET_PROFILE_VALUE} (included devices: ${TARGET_INCLUDED_DEVICES})."
    log_success "Tailscale packages successfully configured."
}

# Main Execution Flow
main() {
    # Check if we should skip the setup phase (e.g. if we are just running a custom command)
    local run_setup=true
    if [[ "$1" == "clean" || "$1" == "dirclean" || "$1" == "distclean" ]]; then
        run_setup=false
    fi

    if [ "$run_setup" = true ]; then
        update_feeds
        configure_tailscale
    fi

    # Parallel CPU cores detection
    local num_cpus
    if command -v nproc &>/dev/null; then
        num_cpus=$(nproc)
    else
        num_cpus=4
    fi
    log_info "Using ${num_cpus} CPU cores for compilation speed."

    # Build or run requested target
    if [ $# -gt 0 ]; then
        log_info "Running: ./scripts/dockerbuild make PROFILE=${TARGET_PROFILE_VALUE} INCLUDED_DEVICES=${TARGET_INCLUDED_DEVICES} DEVICE_DTS=${TARGET_DEVICE_DTS} $*"
        ./scripts/dockerbuild make PROFILE="${TARGET_PROFILE_VALUE}" INCLUDED_DEVICES="${TARGET_INCLUDED_DEVICES}" DEVICE_DTS="${TARGET_DEVICE_DTS}" "$@" -j${num_cpus}
    else
        log_info "Starting rut206 image build with: ./scripts/dockerbuild make PROFILE=${TARGET_PROFILE_VALUE} INCLUDED_DEVICES=${TARGET_INCLUDED_DEVICES} DEVICE_DTS=${TARGET_DEVICE_DTS} target/linux/install"
        ./scripts/dockerbuild make PROFILE="${TARGET_PROFILE_VALUE}" INCLUDED_DEVICES="${TARGET_INCLUDED_DEVICES}" DEVICE_DTS="${TARGET_DEVICE_DTS}" -j${num_cpus} V=sc
    fi
}

main "$@"
