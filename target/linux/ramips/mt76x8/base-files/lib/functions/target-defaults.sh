#!/bin/sh

. /lib/functions/uci-defaults.sh

ucidef_target_defaults() {
	local model="$1"
	local hw_ver="$2"
	local branch="$3"

	case "$model" in
	RUT9*)
		# set up MAC addresses
		ucidef_set_interface_default_macaddr "lan" "$(mtd_get_mac_binary config 0x0)"
		ucidef_set_interface_default_macaddr "wan" "$(macaddr_add "$(mtd_get_mac_binary config 0x0)" 1)"

		# set up io
		[ "${model:7:1}" = "6" ] || [ "$branch" = "A" ] && ucidef_unset_hwinfo ios

		# set up modem
		[ "${model:5:1}" = "1" ] && \
			ucidef_add_static_modem_info "$model" "1-1" "2" "primary"

		# set sd card
		[ "${model:5:1}" = "6" ] && [ "$hw_ver" -gt 4 ] && ucidef_set_hwinfo sd_card

		[ "${model:5:1}" = "6" ] && \
			ucidef_add_static_modem_info "$model" "1-1.4" "2" "primary" "gps_out"

		# set up eSIM (special device code, before SIM config)
		[ "${model:7:1}" = "1" ] && [ "${model::6}" = "RUT901" ] && ucidef_set_esim

		# set up PoE
		if [ "$branch" = "A" ]; then
			ucidef_set_hwinfo poe
			ucidef_set_poe 1 3 "_lan1" "4" 30000 "_lan2" "4" 30000 "_wan4" "4" 30000
			ucidef_set_poe_chip "0X2F" "1:_wan4" "3:_lan2" "4:_lan1"
		fi
		;;
	DAP14*)
		# set up MAC addresses
		ucidef_set_interface_default_macaddr "lan" "$(mtd_get_mac_binary config 0x0)"
		;;
	RUT14*)
		# set up MAC addresses
		ucidef_set_interface_default_macaddr "lan" "$(mtd_get_mac_binary config 0x0)"
		ucidef_set_interface_default_macaddr "wan" "$(macaddr_add "$(mtd_get_mac_binary config 0x0)" 1)"
		;;
	RUT2*)
		# set up MAC addresses
		ucidef_set_interface_default_macaddr "lan" "$(mtd_get_mac_binary config 0x0)"
		ucidef_set_interface_default_macaddr "wan" "$(macaddr_add "$(mtd_get_mac_binary config 0x0)" 1)"

		# set up modem
		case "${model:5:1}" in
		4) ucidef_add_static_modem_info "$model" "1-1.2" "2" "primary" "gps_out" ;;
		6) ucidef_add_static_modem_info "$model" "1-1.2" "2" "primary" ;;
		*) ucidef_add_static_modem_info "$model" "1-1" "1" "primary" ;;
		esac

		# set up io
		[ "${model:6:1}" = "1" ] && ucidef_unset_hwinfo ios

		# set up eSIM
		[ "${model:6:1}" = "2" ] && [ "${model::6}" = "RUT241" ] && {
			ucidef_set_esim
			ucidef_set_hwinfo dual_sim
		}

		# set up dual_sim
		ucidef_check_dual_sim
		;;
	RUT3*)
		# set up MAC addresses
		[ "${model:4:2}" != "01" ] && \
			ucidef_set_interface_default_macaddr "lan" "$(mtd_get_mac_binary config 0x0)"
		ucidef_set_interface_default_macaddr "wan" "$(macaddr_add "$(mtd_get_mac_binary config 0x0)" 1)"

		# set up modem
		[ "${model:4:1}" = "6" ] && \
		ucidef_add_static_modem_info "$model" "1-1" "primary"

		# set up io
		[ "${model:7:1}" = "1" ] && ucidef_unset_hwinfo ios
		;;
	TRB2*)
		#Serials are defined here instead of family.mk as they depend on device's hardware branch
		ucidef_add_serial_capabilities "rs485"\
		"300 600 1200 2400 4800 9600 19200 38400 57600 115200 230400"\
		"5 6 7 8"\
		"xon/xoff none"\
		"1 2"\
		"even odd mark space none"\
		"half full"\
		"/tty/ttyS1"
		
		if [ "${model::6}" = "TRB246" ] && [ "$branch" = "S" ]; then
			ucidef_add_static_modem_info "$model" "1-1" "primary"
			ucidef_unset_hwinfo gps
			ucidef_unset_hwinfo rs232
			# This device has a unique path since it does not have a USB hub
			ucidef_check_path usb_check /sys/bus/usb/drivers/usb/1-1/1-1:1.3 reboot
		else
			ucidef_check_path usb_check /sys/bus/usb/drivers/usb/1-1/1-1.4 reboot
			ucidef_add_serial_capabilities "rs232"\
			"300 600 1200 2400 4800 9600 19200 38400 57600 115200"\
			"7 8"\
			"rts/cts xon/xoff none"\
			"1 2"\
			"even odd mark space none"\
			"none"\
			"/usb1/1-1/1-1.3/"

			if [ "${model::6}" = "TRB236" ]; then
				ucidef_add_static_modem_info "$model" "1-1.4" "primary"
			else
				ucidef_add_static_modem_info "$model" "1-1.4" "primary" "gps_out"
			fi
		fi
		;;
	TAP1*)
		# set up modem
		ucidef_set_interface_default_macaddr "lan" "$(mtd_get_mac_binary config 0x0)"
		;;
	OTD1*)
		# set up MAC addresses
		ucidef_set_interface_default_macaddr "lan" "$(mtd_get_mac_binary config 0x0)"

		# set up modem
		ucidef_add_static_modem_info "$model" "1-1" "primary"
		;;
	esac
}
