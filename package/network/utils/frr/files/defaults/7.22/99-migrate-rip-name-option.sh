#!/bin/sh

. /lib/functions.sh

UCI_CONFIG_DIR="${UCI_CONFIG_DIR:-/etc/config}"
[ -f "$UCI_CONFIG_DIR/rip" ] || exit 0

add_name_option() {
	local section="$1"
	local name

	config_get name "$section" "name"
	[ -n "$name" ] && return

	uci_set "rip" "$section" "name" "$section"
}

config_load rip
for s in rip_interface rip_access_list; do
	config_foreach add_name_option "$s"
done
uci_commit "rip"

exit 0
