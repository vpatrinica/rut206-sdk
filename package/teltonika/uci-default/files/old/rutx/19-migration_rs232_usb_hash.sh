#!/bin/sh

. /lib/functions.sh

rm_section() {
	uci_remove "rs" "rs232_usb"
	uci_commit rs
	exit 0
}

# delete the section if usb_serial has never been configured or no adapter is currently present
uci_get "rs" "rs232_usb" "type" >&- || rm_section
first_inserted=$(basename "$(ls -tr1 /dev/rs232_usb_* | head -n 1)") 2>&- || rm_section

uci_set "rs" "rs232_usb" "id" "${first_inserted##*_}"
uci_set "rs" "rs232_usb" "name" "Unnamed"
uci_rename "rs" "rs232_usb" "$first_inserted"
uci_commit rs

exit 0
