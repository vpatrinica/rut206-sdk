#!/bin/sh

. /lib/functions.sh

config_load siteman

get_dhcp_option() {
	local opt
	config_get opt general dhcp_option 43
	echo "$opt"
}

get_dhcp_option_in_use() {
	local opt
	config_get opt general dhcp_option_in_use ""
	echo "$opt"
}

save_dhcp_option_in_use() {
	local opt="$1"
	uci -q set siteman.general.dhcp_option_in_use="$opt"
	uci commit siteman
}

clear_dhcp_option_in_use() {
	uci -q delete siteman.general.dhcp_option_in_use
	uci commit siteman
}

remove_dhcp_option() {
	local name="$1"
	local dhcp_opt="$2"

	for opt in $(uci -q get dhcp."$name".dhcp_option); do
		case "$opt" in
			"${dhcp_opt}",*)
				uci del_list dhcp."$name".dhcp_option="$opt"
				DHCP_OPT_CHANGED=1
				;;
		esac
	done
}

action_add() {
	local dhcp_opt
	DHCP_OPT_CHANGED=0

	dhcp_opt=$(get_dhcp_option)

	for iface in $(ubus list | grep -o 'network\.interface\.lan[^.]*'); do
		local name="${iface##*.}"
		local ip

		ip=$(ubus call "$iface" status | jsonfilter -e '@["ipv4-address"][0].address')
		[ -z "$ip" ] && continue

		remove_dhcp_option "$name" "$dhcp_opt"

		uci add_list dhcp."$name".dhcp_option="${dhcp_opt},$ip"
		DHCP_OPT_CHANGED=1
	done

	[ "$DHCP_OPT_CHANGED" = "1" ] && {
		uci commit dhcp
		/etc/init.d/dnsmasq reload
	}

	save_dhcp_option_in_use "$dhcp_opt"
}

action_remove() {
	local dhcp_opt
	DHCP_OPT_CHANGED=0

	dhcp_opt=$(get_dhcp_option_in_use)
	[ -z "$dhcp_opt" ] && return

	for name in $(uci -q show dhcp | grep '\.dhcp_option=' | grep "'${dhcp_opt}," | \
			sed "s/dhcp\.\([^.]*\)\..*/\1/" | sort -u); do
		remove_dhcp_option "$name" "$dhcp_opt"
	done

	[ "$DHCP_OPT_CHANGED" = "1" ] && {
		uci commit dhcp
		/etc/init.d/dnsmasq reload
	}

	clear_dhcp_option_in_use
}

action_update() {
	local old_opt new_opt enabled

	config_get enabled general enabled 0
	if [ "$enabled" != "1" ]; then
		action_remove
		return
	fi

	old_opt=$(get_dhcp_option_in_use)
	new_opt=$(get_dhcp_option)

	if [ -n "$old_opt" ] && [ "$old_opt" != "$new_opt" ]; then
		action_remove
	fi

	action_add
}

case "$1" in
	add)    action_add    ;;
	remove) action_remove ;;
	update) action_update ;;
	*)
		echo "Usage: $0 {add|remove|update}" >&2
		exit 1
		;;
esac
