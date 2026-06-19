#!/bin/sh

. /lib/functions.sh

UCI_CONFIG_DIR="${UCI_CONFIG_DIR:-/etc/config}"
[ -f "$UCI_CONFIG_DIR/bgp" ] || exit 0

add_name_option() {
	local section="$1"
	local name

	config_get name "$section" "name"
	[ -n "$name" ] && return

	uci_set "bgp" "$section" "name" "$section"
}

config_load bgp
for s in bgp_instance bgp_peer bgp_peer_group bgp_route_maps; do
	config_foreach add_name_option "$s"
done
uci_commit "bgp"

exit 0
