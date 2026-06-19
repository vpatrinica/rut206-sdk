#!/bin/bash

extract_pkg_data() {
	local PKG_NAME="$1"
	local APP_NAME=""
	local TLT_NAME=""

	local PKG_INFO="$TOPDIR/tmp/.packageinfo"

	local in_package_section=0
	while IFS= read -r line; do
		if [[ "$line" == "Package: $PKG_NAME" ]]; then
			in_package_section=1
			continue
		elif [[ "$line" =~ ^Package:\  ]]; then
			if [[ $in_package_section -eq 1 ]]; then
				break
			fi
			continue
		fi
		if [[ $in_package_section -eq 1 ]]; then
			if [[ "$line" =~ ^AppName:\ (.*) ]]; then
				APP_NAME="${BASH_REMATCH[1]}"
			elif [[ "$line" =~ ^tlt_name:\ (.*) ]]; then
				TLT_NAME="${BASH_REMATCH[1]}"
			fi
			if [[ -n "$APP_NAME" && -n "$TLT_NAME" ]]; then
				break
			fi
		fi
	done < "$PKG_INFO"

	echo "$PKG_NAME: APP_NAME=$APP_NAME; TLT_NAME=$TLT_NAME" >>"${OUTPUT_PATH}"
}

generate_ipk_package_list() {
	rm -f "${OUTPUT_PATH}"
	touch "${OUTPUT_PATH}"

	jq -r "keys | .[]" "$TOPDIR/ipk_packages.json" | while read -r m; do
		if grep -qw "CONFIG_PACKAGE_$m=m" "$TOPDIR/.config"; then
			extract_pkg_data "$m"
		fi
	done
}

main() {
	OUTPUT_PATH="$1"
	TOPDIR="$2"

	if [ -z "$OUTPUT_PATH" ] || [ -z "$TOPDIR" ]; then
		echo "Usage: $0 <output_path> <topdir>"
		exit 1
	fi

	echo "Generating IPK package list in $OUTPUT_PATH"
	generate_ipk_package_list
}

main "$1" "$2"
