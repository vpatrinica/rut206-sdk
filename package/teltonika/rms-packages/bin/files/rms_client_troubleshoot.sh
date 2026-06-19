cloud_solutions_hook() {
	local log_file="${PACK_DIR}cloud_solutions.log"
	troubleshoot_init_log "CLOUD SOLUTIONS INFO" "$log_file"
	# RMS
	troubleshoot_add_log "RMS" "$log_file"
	rms_ubus_res=$(ubus call rms get_status 2>&1)
	printf "%s:\n%s\n\n%s\n" "rms get_status" "$rms_ubus_res" >> "$log_file"
}

troubleshoot_hook_init cloud_solutions_hook
