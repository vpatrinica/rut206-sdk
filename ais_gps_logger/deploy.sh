#!/usr/bin/env bash

# Deployment script for the AIS/GPS logger service on Teltonika RUTM09.
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

# Configuration
DEVICE_IP="${DEVICE_IP:-192.168.0.1}"
DEVICE_USER="${DEVICE_USER:-root}"
DEVICE_PASS="${DEVICE_PASS:-AVPteltonika123$}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

check_sshpass() {
    if ! command -v sshpass &>/dev/null; then
        log_err "sshpass is not installed on the local machine. Please install it with: sudo apt install sshpass"
        exit 1
    fi
}

deploy() {
    check_sshpass
    export SSHPASS="${DEVICE_PASS}"
    local scp_opts="-o StrictHostKeyChecking=no -o ServerAliveInterval=15"
    local ssh_opts="-o StrictHostKeyChecking=no"

    log_info "Deploying AIS/GPS logger service to ${DEVICE_USER}@${DEVICE_IP}..."

    # Ensure remote directories exist
    log_info "Creating remote directories..."
    sshpass -e ssh ${ssh_opts} "${DEVICE_USER}@${DEVICE_IP}" "mkdir -p /usr/local/bin"

    # Copy daemon script
    log_info "Copying daemon script..."
    sshpass -e scp ${scp_opts} "ais_gps_logger.sh" "${DEVICE_USER}@${DEVICE_IP}:/usr/local/bin/ais_gps_logger.sh"

    # Copy init.d script
    log_info "Copying init script..."
    sshpass -e scp ${scp_opts} "ais_gps_logger.init" "${DEVICE_USER}@${DEVICE_IP}:/etc/init.d/ais_gps_logger"

    # Set permissions, enable, and start service
    log_info "Configuring and starting service on the router..."
    sshpass -e ssh ${ssh_opts} "${DEVICE_USER}@${DEVICE_IP}" /bin/sh << 'ENDSSH'
        set -e
        # Set executable permissions
        chmod +x /usr/local/bin/ais_gps_logger.sh
        chmod +x /etc/init.d/ais_gps_logger

        # Enable and restart service
        /etc/init.d/ais_gps_logger enable
        /etc/init.d/ais_gps_logger restart

        # Allow service to start
        sleep 3

        echo "=== Service Status ==="
        /etc/init.d/ais_gps_logger status 2>/dev/null || echo "Status command not supported, checking processes..."
        
        echo "=== Running Processes ==="
        pgrep -fl ais_gps_logger || echo "  NOT running!"

        echo "=== System Logs ==="
        logread | grep -E "ais_gps_logger" | tail -n 10 || true

        echo "=== Output Directory Check ==="
        ls -la /usr/local/mnt/data/

        echo "=== Verifying GPS FIFO stream (waiting 3 seconds for data...) ==="
        if [ -p /mnt/gps.fifo ]; then
            timeout 3 cat /mnt/gps.fifo || echo "Finished reading from FIFO."
        else
            echo "Error: /mnt/gps.fifo does not exist!"
        fi
ENDSSH

    log_success "Deployment and startup completed successfully!"
}

deploy
