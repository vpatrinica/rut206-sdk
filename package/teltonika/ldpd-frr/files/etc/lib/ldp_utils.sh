#!/bin/sh

LDP_CONFIG="/var/run/frr/ldpd.conf"

xappend() {
	local file="$1"
	shift
	echo "$@" >> "$file"
}

xappend_list() {
	local file="$1"
	shift
	if empty_var_check "$@"; then
		for i in $2
		do
			echo "$1 $i" >> "$file"
		done
	fi
}

ldp_get_status() {
	config_get enabled "ldp" "enabled" "0"
	[ "$enabled" == "0" ] && return 1

	return 0
}

ldp_parse_general() {
	local id
	local transport_address
	local ifname
	local section="$1"
	local LDP_CONFIG="/var/run/frr/ldpd.conf"

	config_get id "$section" id
	config_get transport_address "$section" transport_address
	config_get ifname "$section" ifname

	xappend      "$LDP_CONFIG" "mpls ldp"
	xappend      "$LDP_CONFIG" "router-id" "$id"
	xappend      "$LDP_CONFIG" "address-family ipv4"
	xappend	     "$LDP_CONFIG" "discovery transport-address" "$transport_address"
	xappend_list "$LDP_CONFIG" "interface" "$ifname"

	echo "" >> "$LDP_CONFIG"

	write_mpls_sysctl "$ifname"
}

ldp_utils_parse_config() {

	local LDP_CONFIG="/var/run/frr/ldpd.conf"

	config_load mpls

	ldp_get_status || return 0

	config_foreach ldp_parse_general ldp_general
}

write_mpls_sysctl() {
	local ifnames="$1"
	# No validation - 0 or Loose validation - 2 works for MPLS
	[ $(sysctl -n net.ipv4.conf.all.rp_filter) -eq 1 ] && sysctl -wq "net.ipv4.conf.all.rp_filter=2"
	sysctl -wq "net.mpls.platform_labels=1048575"
	sysctl -wq "net.mpls.conf.lo.input=1"

	for ifname in $ifnames; do
		sysctl -wq "net.mpls.conf.$ifname.input=1" 2>/dev/null
	done

}

