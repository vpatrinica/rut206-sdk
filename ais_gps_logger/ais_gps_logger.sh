#!/bin/sh

# Configurable parameters
DEVICE="${1:-/dev/ttyACM0}"
BAUD="38400"
DATA_DIR="/usr/local/mnt/data"
FIFO_PATH="/mnt/gps.fifo"
UDP_PORT="9999"

# Auto-detect device if default is not available
if [ ! -c "$DEVICE" ]; then
    if [ -c "/dev/ACM0" ]; then
        DEVICE="/dev/ACM0"
    elif [ -c "/dev/usb_serial_b96fb9d" ]; then
        DEVICE="/dev/usb_serial_b96fb9d"
    fi
fi

# Ensure data directory and FIFO exist
mkdir -p "$DATA_DIR"
mkdir -p "$(dirname "$FIFO_PATH")"
if [ ! -p "$FIFO_PATH" ]; then
    rm -f "$FIFO_PATH"
    mkfifo "$FIFO_PATH"
fi

# Find socat path
SOCAT_BIN=$(which socat 2>/dev/null || echo "/usr/local/usr/bin/socat")

if [ ! -x "$SOCAT_BIN" ]; then
    logger -t ais_gps_logger "Error: socat not found or not executable"
    exit 1
fi

# Start the UDP-to-FIFO bridge in the background.
# This bridge reads GPS sentences from the local UDP port and writes them to the FIFO.
# If the FIFO has no reader, this background process will block, but the main pipeline
# will continue running as the kernel discards the UDP packets.
# When a reader connects, the bridge immediately forwards the GPS stream.
logger -t ais_gps_logger "Starting UDP-to-FIFO bridge on port $UDP_PORT -> $FIFO_PATH"
while true; do
    "$SOCAT_BIN" -u UDP4-RECV:"$UDP_PORT" FILE:"$FIFO_PATH" 2>/dev/null
    sleep 1
done &
BRIDGE_PID=$!

# Ensure the background bridge process is terminated when this script exits
cleanup() {
    logger -t ais_gps_logger "Stopping AIS/GPS logger and bridge..."
    kill "$BRIDGE_PID" 2>/dev/null
    wait "$BRIDGE_PID" 2>/dev/null
}
trap cleanup EXIT INT TERM

# High-performance awk script:
# 1. AIS sentences (!) are formatted as CSV and written directly to daily files.
# 2. GPS sentences ($) are printed to stdout (piped to the non-blocking UDP sender).
AWK_SCRIPT='
{
    # Remove trailing carriage return
    sub(/\r$/, "")

    # Identify sentence type and route
    if ($0 ~ /^!/) {
        # AIS sentence: log to daily CSV
        prefix = "ais"
        ts_sec = systime()
        timestamp = strftime("%Y-%m-%dT%H:%M:%S%z", ts_sec)
        file_date = strftime("%Y%m%d", ts_sec)
        filename = DATA_DIR "/" file_date "-" prefix ".csv"

        if (!(filename in seen_files)) {
            exists = 0
            if ((getline dummy < filename) > 0) {
                exists = 1
            }
            close(filename)
            if (!exists) {
                print "timestamp,sentence" > filename
            }
            seen_files[filename] = 1
        }

        escaped = $0
        gsub(/"/, "\"\"", escaped)
        print timestamp ",\"" escaped "\"" >> filename
        fflush(filename)

    } else if ($0 ~ /^\$/) {
        # GPS sentence: print to stdout to be piped to the UDP bridge
        print $0
        fflush("/dev/stdout")
    }
}
'

logger -t ais_gps_logger "Starting AIS/GPS logger on $DEVICE at $BAUD baud"

while true; do
    if [ -c "$DEVICE" ]; then
        # Run socat on the serial port, pipe to awk, and pipe awk's stdout (GPS sentences) to UDP
        "$SOCAT_BIN" -u FILE:"$DEVICE",b"$BAUD",raw,echo=0,clocal=1 STDOUT 2>/dev/null | \
            awk -v DATA_DIR="$DATA_DIR" "$AWK_SCRIPT" | \
            "$SOCAT_BIN" -u STDIN UDP4-SENDTO:127.0.0.1:"$UDP_PORT" 2>/dev/null
        
        logger -t ais_gps_logger "Main pipeline exited. Reconnecting in 5 seconds..."
    else
        logger -t ais_gps_logger "Device $DEVICE not found. Retrying in 5 seconds..."
    fi
    sleep 5
done
