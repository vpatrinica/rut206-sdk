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

# 1. Copy Tailscale support packages from Reference SDK if missing
copy_packages() {
    local target_dir="${SDK_DIR}/package/feeds/vuci"
    local apps=("vuci-app-tailscale-api" "vuci-app-tailscale-ui")

    for app in "${apps[@]}"; do
        if [ ! -d "${target_dir}/${app}" ]; then
            if [ -d "${REF_SDK_DIR}/package/feeds/vuci/${app}" ]; then
                log_info "Copying ${app} from reference SDK..."
                mkdir -p "${target_dir}"
                cp -r "${REF_SDK_DIR}/package/feeds/vuci/${app}" "${target_dir}/${app}"
                log_success "${app} copied successfully."
            else
                log_warn "Reference app ${app} not found in ${REF_SDK_DIR}."
            fi
        else
            log_info "${app} already exists in workspace."
        fi
    done
}

# 2. Update and Install Feeds
update_feeds() {
    log_info "Updating package feeds inside Docker..."
    ./scripts/dockerbuild ./scripts/feeds update -a
    log_info "Installing package feeds inside Docker..."
    ./scripts/dockerbuild ./scripts/feeds install -a
    log_success "Feeds updated and installed."
}

# 3. Configure Tailscale and its VuCI applications in .config
configure_tailscale() {
    log_info "Configuring Tailscale packages in .config..."
    if [ ! -f .config ]; then
        log_warn ".config not found. Running default configuration first..."
        ./scripts/dockerbuild make defconfig
    fi

    # Remove existing definitions to avoid duplicates/conflicts
    sed -i '/CONFIG_PACKAGE_tailscale/d' .config
    sed -i '/CONFIG_PACKAGE_vuci-app-tailscale-api/d' .config
    sed -i '/CONFIG_PACKAGE_vuci-app-tailscale-ui/d' .config

    # Append the configuration options
    echo "CONFIG_PACKAGE_tailscale=y" >> .config
    echo "CONFIG_PACKAGE_vuci-app-tailscale-api=y" >> .config
    echo "CONFIG_PACKAGE_vuci-app-tailscale-ui=y" >> .config

    log_info "Resolving configuration dependencies (make defconfig)..."
    ./scripts/dockerbuild make defconfig
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
        copy_packages
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
        log_info "Running: ./scripts/dockerbuild make $@"
        ./scripts/dockerbuild make "$@"
    else
        log_info "Starting full firmware build with: ./scripts/dockerbuild make -j${num_cpus}"
        ./scripts/dockerbuild make -j"${num_cpus}"
    fi
}

main "$@"
