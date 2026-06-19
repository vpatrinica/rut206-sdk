#!/bin/sh

# from network conf device and interface sections, remove redundant entries of default HW mac

. /lib/functions.sh
. /usr/share/libubox/jshn.sh

ifaces() {
	local section="$1" mac ifname bjson_mac

	mac="$(uci_get "network" "$section" "macaddr")" || return 0
	ifname="$(uci_get "network" "$section" "$IFVAR")" || return 0 # network conf too malformed for config_get

	json_select "$ifname" || return 0
		json_get_var bjson_mac 'macaddr' || return 0
	json_select ..

	[ "$(to_lower $bjson_mac)" != "$(to_lower $mac)" ] && return 0
	uci_remove "network" "$section" "macaddr"
}

json_load_file /etc/board.json
json_is_a 'network-device' object || exit 0
json_select 'network-device'

config_load "network" || exit 0
IFVAR=ifname
config_foreach ifaces "interface"
IFVAR=name
config_foreach ifaces "device"

uci_commit "network"
