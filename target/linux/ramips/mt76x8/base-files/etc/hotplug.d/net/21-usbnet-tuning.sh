[ "$ACTION" = "add" ] || exit

# interface belongs to a usbnet driver
# this check is not perfect (misses "eth*" usbnet intefaces),
# but it should cover all drivers with NAPI implementation
[ "${DEVICENAME:0:3}" == "usb" ] || [ "${DEVICENAME:0:4}" == "wwan" ] && {
        echo 0 > "/sys/${DEVPATH}/threaded"
        ethtool -K "$DEVICENAME" gro off
        exit
}

# device is a virtual interface to a usbnet interface
[ -d "/sys/${DEVPATH}/lower_wwan"* ] || [ -d "/sys/${DEVPATH}/lower_usb"* ] && {
        ethtool -K "$DEVICENAME" gro off
        exit
}