. /lib/upgrade/common.sh

PART_NAME=firmware
REQUIRE_IMAGE_METADATA=1

platform_check_image() {
	return 0
}

platform_do_upgrade() {
	default_do_upgrade "$1"
}

compatible_to_ec200() {
	{ ! find_hw_mod "2c7c_6005"; } && {
		echo "EC200* modem detected but fw does not support it"
		return 1
	}
	return 0
}

compatible_to_ala440() {
	{ ! find_hw_mod "ala440"; } && [ "$vendor" = "1d12" ] && [[ $product =~ "^010(1|2)" ]] && {
		echo "Found ALA440 modem $vendor:$product, but firmware does not support it"
		return 1
	}
	return 0
}

check_hw_mod() {
	local model min_hwver hwmod
	model="$1"
	min_hwver="$2"
	hwmod="$3"

	if [ "${board:3:3}" = "$model" ]; then
		[ "$hwver" -ge "$min_hwver" ] && { ! find_hw_mod "$hwmod"; } && {
			echo "Found new hardware revision this firmware does not support it"
			return 1
		}
	fi
	return 0
}

platform_check_hw_support() {

	local adc_ver board exp hwver

	board="$(cat /sys/mnf_info/name)"
	hwver="$(cat /sys/mnf_info/hwver)"
	hwbranch="$(cat /sys/mnf_info/branch)"

	eval "$( jsonfilter -q -i "/etc/board.json" \
		-e "vendor=@['modems'][@.builtin=true].vendor" \
		-e "product=@['modems'][@.builtin=true].product" \
		)"

	exp="^RUT2(00|41|60)"
	[[ $board =~ $exp ]] && {
		{ ! prepare_metadata_hw_mods "$1"; } && return 1
		{ ! check_hw_mod "260" 3 "260v3"; } && return 1
		{ ! check_hw_mod "241" 5 "241v5"; } && return 1
		{ ! check_hw_mod "200" 5 "200v5"; } && return 1
		{ ! compatible_to_ala440; } && return 1
	}

	exp="^TRB2(46)"
	[[ $board =~ $exp ]] && {
		{ ! prepare_metadata_hw_mods "$1"; } && return 1
		{ ! check_hw_mod "246" 5 "246v5"; } && return 1
		[ "$hwbranch" = "S" ] && { ! find_hw_mod "246hwS"; } && return 1
	}


	exp="^RUT9(51|56|01|06)"
	[[ ! $board =~ $exp ]] && return 0

	{ ! prepare_metadata_hw_mods "$1"; } && return 1

	[ "$(jsonfilter -i /etc/board.json -e '@.hwinfo.esim')" = "true" ] && \
		{ ! find_hw_mod "esim"; } && {
			echo "Device have ESIM hardware but this fw does not support it"
			return 1
		}

	[ -d "/sys/bus/usb/devices/1-1.3/1-1.3:1.0/tty/ttyCH343USB0" ]  && \
		{ ! find_hw_mod "CH343"; } && {
			echo "Found new RS232 chip but this fw does not support it"
			return 1
		}

	adc_ver="$(cat /sys/class/hwmon/hwmon0/device/name)"
	[ "$adc_ver" = "tla2021" ] && { ! find_hw_mod "TLA2021"; } && {
		echo "Found new adc chip TLA2021 but this fw does not support it"
		return 1
	}

	{ ! compatible_to_ala440; } && return 1

	[ -z "$vendor" ] || [ -z "$product" ] && {
		echo "Unable to determine current modem model"
		# FW should satisfy all contitions
		compatible_to_ec200
		return "$?"
	}

	[ "${vendor}:${product}" != "2c7c:6005" ] && return 0

	compatible_to_ec200

	return "$?"
}
