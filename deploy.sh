#!/usr/bin/env bash

# Easy deployment wrapper for RutOS SDK.
# Can deploy built package IPKs or flash full firmware to a Teltonika router.

set -e

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

# Configuration Defaults (can be overridden via environment variables)
DEVICE_IP="${DEVICE_IP:-192.168.1.1}"
DEVICE_USER="${DEVICE_USER:-root}"

# Load a local .env file if present. This lets you keep secrets out of git
# by adding a .env file to .gitignore or exporting DEVICE_PASS in your shell.
if [ -f .env ]; then
    # shellcheck disable=SC1091
    set -o allexport
    # shellcheck source=/dev/null
    source .env
    set +o allexport
fi

# Do NOT provide a default password here. Set DEVICE_PASS in your environment
# or in a local .env file (recommended). If empty, the script will prompt.
DEVICE_PASS="${DEVICE_PASS:-}"

SDK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SDK_DIR}"

check_sshpass() {
    if ! command -v sshpass &>/dev/null; then
        log_err "sshpass is not installed. Please install it with: sudo apt install sshpass"
        exit 1
    fi
}

deploy_packages() {
    check_sshpass
    log_info "Locating Tailscale IPKs..."

    local ipk_tailscale ipk_tailscaled
    ipk_tailscaled=$(find bin/packages -name "tailscaled_*.ipk" | head -n 1)
    ipk_tailscale=$(find bin/packages -name "tailscale_*.ipk" ! -name "tailscaled_*" | head -n 1)

    if [ -z "${ipk_tailscaled}" ]; then
        log_err "tailscaled IPK not found in bin/packages/. Did you run build.sh first?"
        exit 1
    fi

    export SSHPASS="${DEVICE_PASS}"
    local scp_opts="-o StrictHostKeyChecking=no -o ServerAliveInterval=15 -o ServerAliveCountMax=8 -l 2048"
    local ssh_opts="-o StrictHostKeyChecking=no"

    # Detect the 'programs' USB partition mount point on the router.
    # RutOS auto-mounts USB drives under /usr/local/mnt/. We look for the partition
    # labelled 'programs' (the 1GB ext4 partition created for this purpose).
    log_info "Detecting USB programs partition on router..."
    local usb_mount
    usb_mount=$(sshpass -e ssh ${ssh_opts} "${DEVICE_USER}@${DEVICE_IP}" \
        "block info 2>/dev/null | grep 'LABEL=\"programs\"' | grep -o 'MOUNT=\"[^\"]*\"' | cut -d'\"' -f2")

    if [ -z "${usb_mount}" ]; then
        log_err "USB 'programs' partition not found on router. Is the USB drive plugged in?"
        log_err "Expected a partition labelled 'programs' (ext4, 1GB) on the USB drive."
        exit 1
    fi
    log_info "Using USB programs partition at: ${usb_mount}"

    # Extract binaries locally from IPKs. We bypass opkg entirely — it extracts to
    # /tmp first and the 23-27M Go binaries exceed the router's available tmpfs.
    local work_dir
    work_dir="$(mktemp -d)"
    trap 'rm -rf "${work_dir}"' EXIT

    log_info "Extracting binaries from IPKs..."
    mkdir -p "${work_dir}/tsd" "${work_dir}/ts"
    cp "${ipk_tailscaled}" "${work_dir}/tsd/pkg.tar.gz"
    (cd "${work_dir}/tsd" && tar -xzf pkg.tar.gz && tar -xzf data.tar.gz)
    if [ -n "${ipk_tailscale}" ]; then
        cp "${ipk_tailscale}" "${work_dir}/ts/pkg.tar.gz"
        (cd "${work_dir}/ts" && tar -xzf pkg.tar.gz && tar -xzf data.tar.gz)
    fi

    # Patch init script to use the USB mount path (ROM /usr/sbin is read-only squashfs).
    local init_script="${work_dir}/tsd/etc/init.d/tailscale"
    local bin_dir="${usb_mount}/usr/sbin"
    sed -i "s|/usr/sbin/tailscaled|${bin_dir}/tailscaled|g" "${init_script}"

    # Prepare target directory on USB and clean up old overlay binaries
    log_info "Preparing USB target directory and cleaning overlay..."
    sshpass -e ssh ${ssh_opts} "${DEVICE_USER}@${DEVICE_IP}" \
        "mkdir -p '${bin_dir}'; \
         rm -f /usr/local/usr/sbin/tailscale /usr/local/usr/sbin/tailscaled \
               /usr/local/usr/lib/opkg/info/tailscale.* \
               /usr/local/usr/lib/opkg/info/tailscaled.* \
               /var/lock/opkg.lock"

    # SCP tailscaled to USB (large binary; bandwidth-limited to avoid CPU overload)
    log_info "Transferring tailscaled to USB programs partition (~90s)..."
    sshpass -e scp ${scp_opts} \
        "${work_dir}/tsd/usr/sbin/tailscaled" \
        "${DEVICE_USER}@${DEVICE_IP}:${bin_dir}/tailscaled"

    # SCP tailscale CLI to USB (also persistent now, not just /tmp)
    if [ -n "${ipk_tailscale}" ]; then
        log_info "Transferring tailscale CLI to USB programs partition (~75s)..."
        sshpass -e scp ${scp_opts} \
            "${work_dir}/ts/usr/sbin/tailscale" \
            "${DEVICE_USER}@${DEVICE_IP}:${bin_dir}/tailscale"
    fi

    # SCP init script and config
    log_info "Transferring init script and config..."
    sshpass -e scp ${scp_opts} "${init_script}" \
        "${DEVICE_USER}@${DEVICE_IP}:/etc/init.d/tailscale"
    sshpass -e scp ${scp_opts} "${work_dir}/tsd/etc/config/tailscale" \
        "${DEVICE_USER}@${DEVICE_IP}:/etc/config/tailscale"

    # Set permissions, add symlinks into PATH, enable and start service
    log_info "Configuring service..."
    sshpass -e ssh ${ssh_opts} "${DEVICE_USER}@${DEVICE_IP}" /bin/sh -s "${bin_dir}" << 'ENDSSH'
BIN_DIR="$1"
chmod +x "${BIN_DIR}/tailscaled" /etc/init.d/tailscale
[ -f "${BIN_DIR}/tailscale" ] && chmod +x "${BIN_DIR}/tailscale"

# Symlink into /usr/local/usr/sbin (in PATH) so 'tailscale' works without full path
# These are just symlinks — tiny overlay footprint
mkdir -p /usr/local/usr/sbin
ln -sf "${BIN_DIR}/tailscaled" /usr/local/usr/sbin/tailscaled
[ -f "${BIN_DIR}/tailscale" ] && ln -sf "${BIN_DIR}/tailscale" /usr/local/usr/sbin/tailscale

/etc/init.d/tailscale enable
/etc/init.d/tailscale restart
sleep 2
ubus call session reload_acls 2>/dev/null || true
echo "=== tailscaled running ==="
pgrep -l tailscaled || echo "  NOT running"
echo "=== tailscale status ==="
tailscale status 2>&1 || true
echo "=== overlay free ==="
df -h /overlay
ENDSSH

    log_success "Deployment complete!"
    log_info "Both binaries are on the USB programs partition (${usb_mount}/usr/sbin/)."
    log_info "Symlinks added to PATH. Run 'tailscale up' on the router to authenticate."
}

deploy_firmware() {
    check_sshpass
    log_info "Locating built firmware image..."

    # Find the built firmware under bin/targets/ramips/generic/tltFws/
    local fw_dir="bin/targets/ramips/generic/tltFws"
    if [ ! -d "${fw_dir}" ]; then
        log_err "Firmware directory not found: ${fw_dir}. Please run build.sh first."
        exit 1
    fi

    local fw_file
    fw_file=$(find "${fw_dir}" -name "*.bin" | head -n 1)

    if [ -z "${fw_file}" ]; then
        log_err "No compiled firmware .bin found in ${fw_dir}."
        exit 1
    fi

    log_info "Found firmware: $(basename "${fw_file}")"
    log_info "Transferring firmware to router /tmp/fw.bin..."
    export SSHPASS="${DEVICE_PASS}"
    sshpass -e scp -o StrictHostKeyChecking=no "${fw_file}" "${DEVICE_USER}@${DEVICE_IP}:/tmp/fw.bin"

    log_warn "Starting sysupgrade on the router. Note: The router will reboot and disconnect!"
    log_info "Executing sysupgrade -v -n /tmp/fw.bin (this does a clean install)..."
    log_info "If you want to keep configuration, manually run: sysupgrade -v /tmp/fw.bin"
    
    # Run sysupgrade (this will close the connection and reboot the device)
    sshpass -e ssh -o StrictHostKeyChecking=no "${DEVICE_USER}@${DEVICE_IP}" "sysupgrade -v -n /tmp/fw.bin" || {
        log_warn "Connection closed (expected during reboot/upgrade)."
    }

    log_success "Firmware transfer and upgrade command executed successfully. Please wait a few minutes for the device to reboot."
}

show_usage() {
    echo "Usage: $0 [packages|firmware]"
    echo ""
    echo "Options:"
    echo "  packages  - Bundles and deploys built Tailscale IPKs only (faster, no reboot needed)"
    echo "  firmware  - Deploys and flashes the full compiled firmware image (sysupgrade, reboots)"
    echo ""
    echo "Environment Variables (optional):"
    echo "  DEVICE_IP   (default: 192.168.1.1)"
    echo "  DEVICE_USER (default: root)"
    echo "  DEVICE_PASS (default: AVPteltonika123$)"
}

# Main Command Parsing
case "$1" in
    packages|ipk)
        deploy_packages
        ;;
    firmware|fw)
        deploy_firmware
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
