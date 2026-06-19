#!/bin/sh

[ -n "$INCLUDE_ONLY" ] || {
	. /lib/functions.sh
	. /lib/functions/network.sh
	. /lib/netifd/netifd-proto.sh
	init_proto "$@"
}

proto_xfrm_setup() {
	local cfg="$1"
	local mode="xfrm"

	local tunlink ifid mtu zone multicast defaultroute
	config_load ipsec
	config_get gateway "$cfg" gateway
	config_get defaultroute "${cfg}_c" defaultroute
	local active_wan="/tmp/run/mwan3/active_wan"
	json_get_vars tunlink ifid mtu zone multicast

	[ -z "$tunlink" ] && {
		proto_notify_error "$cfg" NO_TUNLINK
		proto_block_restart "$cfg"
		exit
	}

	[ -z "$ifid" ] && {
		proto_notify_error "$cfg" NO_IFID
		proto_block_restart "$cfg"
		exit
	}

	for ip in $(resolveip -t 5 "$gateway"); do
		case "$ip" in
		*:*)
			IP6=1
			;;
		esac
		[ "$defaultroute" -eq 1 ] && [ "$IP6" != 1 ] || continue

		if [ -f "$active_wan" ]; then
			default_int=$(cat "$active_wan")
			case $default_int in
				mob*s*a*) default_int="${default_int}_4" ;;
			esac
			default="$(ubus call network.interface dump | jsonfilter -e '@.interface[@.interface="'"${default_int}"'"].device')"
		fi
		[ -z "$default" ] && default="$(ip route show default | head -n 1 | awk -F"dev " '{print $2}' | sed 's/\s.*$//')"
		res=$(ip route show default dev $default)
		gw="$(echo "$res" | head -n 1 | awk -F"via " '{print $2}' | sed 's/\s.*$//')"
		metric="$(echo "$res" | awk -F"metric " '{print $2}' | sed 's/\s.*$//')"

		[ -n "$gw" ] && ip route add "$ip" via "$gw" dev "$default" metric "$metric" || ip route add "$ip" dev "$default" metric "$metric"
	done

	( proto_add_host_dependency "$cfg" '' "$tunlink" )

	proto_init_update "$cfg" 1

	proto_add_tunnel
	json_add_string mode "$mode"
	json_add_int mtu "${mtu:-1280}"

	json_add_string link "$tunlink"

	json_add_boolean multicast "${multicast:-1}"

	json_add_object 'data'
	[ -n "$ifid" ] && json_add_int ifid "$ifid"
	json_close_object

	proto_close_tunnel

	proto_add_data
	[ -n "$zone" ] && json_add_string zone "$zone"
	proto_close_data

	proto_send_update "$cfg"
}

proto_xfrm_teardown() {
	local cfg="$1"
	config_load ipsec
	config_get gateway "$cfg" gateway
	config_get defaultroute "${cfg}_c" defaultroute "0"
	if [ "$defaultroute" = "1" ]; then
		hosts=$(resolveip -t 5 "$gateway")
		for ip in $hosts; do
			ip route del "$ip"
		done
	fi
}

proto_xfrm_init_config() {
	no_device=1
	available=1

	proto_config_add_int "mtu"
	proto_config_add_string "tunlink"
	proto_config_add_string "zone"
	proto_config_add_int "ifid"
	proto_config_add_boolean "multicast"
}


[ -n "$INCLUDE_ONLY" ] || {
	[ -d /sys/module/xfrm_interface ] || [ -f "/etc/modules.d/xfrm-interface" ] && add_protocol xfrm
}
