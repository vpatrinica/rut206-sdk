#!/bin/sh

[ -z "$1" ] && echo "Error: should be run by udhcpc" && exit 1

get_options() {
	local dhcp_opt=$(uci -q get sitemanc.general.dhcp_option)
	local optvar="opt${dhcp_opt:-43}"

	noopt="/tmp/udhcpc.noopt.${interface:-unknown}"

	eval optval="\$$optvar"

	[ -z "$optval" ] && {
		[ -f "$noopt" ] || logger -t udhcpc "Error: no option $dhcp_opt"
		echo 1 > "$noopt"
		rm -f /tmp/udhcpc.result
		exit 0
	}

	rm -f "$noopt"
	echo "$optval" > /tmp/udhcpc.result
}

case "$1" in
	bound)
		get_options
	;;
esac
