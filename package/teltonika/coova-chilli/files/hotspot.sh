#!/bin/sh

hotspot_hook() {
	local log_file="${PACK_DIR}hotspot.log"

	local state="$(ubus list chilli.* 2>/dev/null)"
	for session in $state; do
		troubleshoot_init_log "Sessions $session" "$log_file"
		troubleshoot_add_log "$(ubus call "$session" list)" "$log_file"
	done

	troubleshoot_init_log "Logs" "$log_file"
	local response="$(/sbin/api GET /hotspot/user_management/status)"
	[ -z "$response" ] && return
	local success="$(echo "$response" | jsonfilter -e '@.http_body.success')"
	[ "$success" != "true" ] && return

	troubleshoot_add_log "$(echo "$response" | jsonfilter -e '@.http_body.data' | lua -e '
	local json = require("luci.jsonc")
	local input = io.read("*a")
	local obj = json.parse(input)
	if obj then
		print(json.stringify(obj, true))
	end
	')" "$log_file"
}

troubleshoot_hook_init hotspot_hook
