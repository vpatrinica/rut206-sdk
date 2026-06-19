#!/bin/sh
# shellcheck disable=3010,3043,2317,3057

. /lib/functions.sh
. /lib/upgrade/common.sh

export CONFFILES=/tmp/profile.conffiles
RM_CONFFILES=/tmp/rm_profile.conffiles
PROFILE_VERSION_FILE=/etc/profile_version
EXCEPTIONS="etc/config/rms_connect_timer etc/config/profiles etc/crontabs/root etc/hosts etc/config/luci etc/config/vuci
	etc/inittab etc/group etc/passwd etc/profile etc/shadow etc/shells etc/sysctl.conf etc/rc.local  etc/config/teltonika
	etc/default-config etc/dropbear/dropbear_ecdsa_host_key etc/dropbear/dropbear_ed25519_host_key
	usr/local/usr/lib/mdcollectd/mdcollectd.db_new.gz usr/local/share/ip_block/attempts.db etc/config/certificates"

EXTRA_FILES="/etc/firewall.user /etc/profile_version"

KNOWN_CLEANS="/etc/config/event_juggler"

TMP_PATH="/tmp/tmp_root/"
MAIN_PATH="$(uci_get profiles general path /etc/profiles)"
CURRENT_PROFILE="$(uci_get profiles general profile default)"

RELOAD_EVENT=1

# rpcd scripts set a umask of 077 while script expects 022
umask 022

log() {
	logger -s -t "$(basename "$0")" "$1"
}

add_uci_conffiles() {
	local opkg_command=""
	local file="$1"
	local misc_files=""

	if [ -f "/bin/opkg" ]; then
		opkg_command="opkg list-changed-conffiles"
	else
		# if opkg doesn't exist, save the entire /etc directory
		find "/etc" -type f -o -type l 2>/dev/null >"$file"
		# exclude these directories
		sed -i "/\/etc\/uci-defaults\//d;
			/\/etc\/init.d\//d;
			/\/etc\/modules-boot.d\//d;
			/\/etc\/modules.d\//d;
			/\/etc\/profiles\//d;
			/\/etc\/rc.button\//d;
			/\/etc\/rc.d\//d;
			/\/etc\/hotplug.d\//d" "$file"
	fi

	misc_files=$(sed -ne '/^[[:space:]]*$/d; /^#/d; p' \
		/etc/sysupgrade.conf /lib/upgrade/keep.d/* /usr/local/lib/upgrade/keep.d/* 2>/dev/null)

	[ -n "$opkg_command" ] && eval "$opkg_command" | sed 's|^/usr/local/etc/|/etc/|' >"$file"
	#Do not qoute ${misc_files} !!!!
	# shellcheck disable=2086 # Splitting is intended here
	[ -n "$misc_files" ] && find ${misc_files} -type f -o -type l 2>/dev/null >>"$file"

	# removes duplicates
	[ -f "$file" ] && {
		local temp="$(sort -u "$file")"
		printf '%s' "$temp" >"$file"
	}

	return 0
}

remove_exceptions() {
	# shellcheck disable=2086 # Splitting is intended here
	sed -i'' -e "$(printf "\,%s,d; " $EXCEPTIONS)" "$1"
}

remove_exceptions_from_file() {
	local dir="$1"
	cd "$dir" || return 1

	# shellcheck disable=2086 # Splitting is intended here
	rm -f $EXCEPTIONS

	cd - >/dev/null || return 1
}

add_extras() {
	# shellcheck disable=2086 # Splitting is intended here
	printf "%s\n" $EXTRA_FILES >>"$CONFFILES"
}

is_switch() {
	[ "$(jsonfilter -q -i /etc/board.json -e '@.hwinfo.switch')" = "true" ]
}

remove_section() {
	local section="$1"
	local config="$2"
	local option="$3"
	local value

	config_get value "$section" "$option" ""
	[ -n "$value" ] && uci_remove "$config" "$section"
}

remove_option() {
	local section="$1"
	local config="$2"
	local option="$3"
	local value

	config_get value "$section" "$option" ""
	[ -n "$value" ] && uci_remove "$config" "$section" "$option"
}

config_remove_if_exists() {
	local config="$1"
	local section="$2"
	local option="$3"
	local action="$4"

	config_load "$config"
	config_foreach "$action" "$section" "$config" "$option"
	uci_commit "$config"
}

update_tmp_md5_config() {
	local profile="$1"
	local cfg_name="$2"
	local md5_file="/etc/profiles/${profile}.md5"

	local cfg_file="${TMP_PATH}etc/config/$cfg_name"
	[ -f "$cfg_file" ] && {
		sed -i "/$cfg_name/d" "$md5_file"
		md5sum "$cfg_file" | sed "s|$TMP_PATH|/|" >>"$md5_file"
	}
}

__fix_conf_files() {
	local profile="$1"
	local uci_dir="$UCI_CONFIG_DIR"

	# Set global uci config dir
	UCI_CONFIG_DIR="${TMP_PATH}etc/config"

	local network_action="remove_section"
	is_switch && {
		network_action="remove_option"
		config_remove_if_exists "tswconfig" "switch_port" "macaddr" "remove_option"
		update_tmp_md5_config "$profile" "tswconfig"
	}

	config_remove_if_exists "network" "device" "macaddr" "$network_action"
	update_tmp_md5_config "$profile" "network"

	# Revert global uci config dir
	UCI_CONFIG_DIR="$uci_dir"
}

__add_conf_files() {
	local profile="$1" filelist="$2"
	local cfg_name misc_files keep_files

	for i in $(grep -sE "^/etc/config/|^/usr/local/etc/config/" "$filelist"); do
		i="${i#/usr/local}"
		cfg_name=$(basename "$i")
		local destination_file="${TMP_PATH}etc/config/$cfg_name"
		# Check if the file already exists in the destination directory
		[ -s "$destination_file" ] && continue
		cp -af "$i" "$destination_file"
		sed -i "/$cfg_name/d" "/etc/profiles/${profile}.md5"
		md5sum "$i" >>"/etc/profiles/${profile}.md5"
	done

	keep_files=$(grep -sE "^/lib/upgrade/keep.d/|^/usr/local/lib/upgrade/keep.d/" "$filelist")
	[ -z "$keep_files" ] && return

	misc_files=$(sed -ne '/^[[:space:]]*$/d; /^#/d; p' ${keep_files} 2>/dev/null)
	[ -n "$misc_files" ] &&
		find ${misc_files} -type f -o -type l >/tmp/keep_files 2> /dev/null
}

__rm_conf_files() {
	local profile=$1 filelist=$2
	local cfg_name keep_files

	for i in $(grep -sE "^/etc/config/|^/usr/local/etc/config/" "$filelist"); do
		i="${i#/usr/local}"
		cfg_name=$(basename "$i")

		rm -f "${TMP_PATH}etc/config/${cfg_name}"
		sed -i "/$cfg_name/d" "/etc/profiles/${profile}.md5"
	done

	keep_files=$(grep -sE "^/lib/upgrade/keep.d/|^/usr/local/lib/upgrade/keep.d/" "$filelist")
	[ -z "$keep_files" ] && return

	for i in $(sed -ne '/^[[:space:]]*$/d; /^#/d; p' ${keep_files} 2>/dev/null); do
		rm -rf "${TMP_PATH:?}${i:1}"
	done
}

__execute_uci_defaults() {
	local profile=$1

	#If version differs execute defaults
	cmp -s "${TMP_PATH}${PROFILE_VERSION_FILE}" /etc/version && return

	#When profile is from previous firmware there can
	#be new configs that were added, need to copy them to profile
	for file in /etc/config/*; do
		target_file="${TMP_PATH}/etc/config/$(basename "$file")"
		if [ ! -e "$target_file" ]; then
			cp -af "$file" "$target_file"
		fi
	done

	#Apply uci defaults only if profile is created on different FW version.
	__uci_apply_defaults "$TMP_PATH"

	#Update profile version
	cp /etc/version "${TMP_PATH}${PROFILE_VERSION_FILE}"

	#Update md5 hashes
	create_md5 "/etc/profiles/${profile}.md5" "$TMP_PATH"
}

__update_tar() {
	local cb=$1
	local filelist=$2
	local profile name

	for profile in /etc/profiles/*.tar.gz; do
		mkdir -p "$TMP_PATH"
		tar xzf "$profile" -C "$TMP_PATH"
		name=$(basename "$profile" .tar.gz)
		$cb "$name" "$filelist"

		# Re-pack profile using -T to not include directories
		# since they would have incorrect permissions
		if [ -s "/tmp/keep_files" ]; then
			cat /tmp/keep_files > /tmp/tar_filelist
			find "$TMP_PATH" -type f -o -type l | sed "s|$TMP_PATH||" >> /tmp/tar_filelist

			# Remove duplicates
			sort -u /tmp/tar_filelist > /tmp/tar_filelist.sorted
			mv /tmp/tar_filelist.sorted /tmp/tar_filelist

			tar czf "$profile" -C "$TMP_PATH" -T /tmp/tar_filelist
		else
			find "$TMP_PATH" -type f -o -type l | sed "s|$TMP_PATH||" | tar czf "$profile" -C "$TMP_PATH" -T -
		fi

		rm -rf "$TMP_PATH" /tmp/keep_files /tmp/tar_filelist
	done
}

fix_configs() {
	__update_tar __fix_conf_files "$1"
}

apply_defaults() {
	case "$1" in
	current)
		# Apply only for current profile (root dir)
		__uci_apply_defaults
		echo '{ "status": '$?' }'
		;;
	all)
		__update_tar __execute_uci_defaults
		echo '{ "status": '$?' }'
		;;
	*)
		echo '{ "status": 22, "error": "type must be '\''current'\'' or '\''all'\''"}'
		return 1
		;;
	esac
}

install_pkg() {
	__update_tar __add_conf_files "$1"
}

remove_pkg() {
	__update_tar __rm_conf_files "$1"
}

do_save_conffiles() {
	local conf_tar=$1

	[ -z "$conf_tar" ] && return 1
	[ -z "$(rootfs_type)" ] && {
		log "Cannot save config while running from ramdisk."
		ask_bool 0 "Abort" && exit
		return 1
	}

	add_uci_conffiles "$CONFFILES"
	# Do not save these configs
	remove_exceptions "$CONFFILES"
	echo -en "\n" >>"$CONFFILES"
	add_extras
	cp /etc/version "$PROFILE_VERSION_FILE"

	tar czf "$conf_tar" -T "$CONFFILES" 2>/dev/null
	rm -f "$CONFFILES" "$PROFILE_VERSION_FILE"
	return 0
}

create_md5() {
	local md5_file=$1
	local base_dir=$2
	[ -z "$md5_file" ] && return 1

	md5sum $base_dir/etc/config/* $base_dir/etc/shadow | grep -vE "profiles|rms_connect_timer" >"$md5_file"
	[ -z "$base_dir" ] || sed -i "s| $base_dir/| /|" "$md5_file"
}

is_legacy_profile() {
	local apply_dir="$1"
	#There is no correct way to indicate legacy profile, so we searching for dinosaurs here
	[ -e "$apply_dir/etc/config/coovachilli" ] && [ -e "$apply_dir/etc/config/sms_gateway" ] &&
		[ -e "$apply_dir/etc/config/data_limit" ]
}

__check_compatibility() {
	local old_major="$1"
	local old_minor="$2"
	local dir="$3"
	local version="${dir##*/}"
	local uci_major="${version%%.*}"
	local uci_minor="${version#*.}"

	# ignore non-numeric directory names
	case "$uci_minor" in
		''|*[!0-9]*) uci_minor="" ;;
		*) ;;
	esac

	[ "$version" = "$uci_minor" ] && uci_minor=""

	[ -n "$uci_major" ] && [ -n "$uci_minor" ] || return 0
	[ "$uci_major" -lt "$old_major" ] && return 1
	[ "$uci_major" -eq "$old_major" ] && [ "$uci_minor" -lt "$old_minor" ] && return 1

	return 0
}

__apply_defaults() {
	local dir="$1"
	find "$dir" -maxdepth 1 -type f | sort -V | while read -r file; do
		( . "$file" 2>/dev/null ) && rm -f "$file"
	done
}

__uci_apply_defaults() {
	local apply_dir="$1"
	local top_dir="/tmp/uci-defaults"

	mkdir -p "$top_dir"
	cp -r /rom/etc/uci-defaults/* "$top_dir/"
	chmod -R +x "$top_dir/"
	[ -z "$(ls -A "$top_dir/")" ] && return 0

	local old_version="$(cat "${apply_dir}${PROFILE_VERSION_FILE}" 2>/dev/null)"
	local new_version="$(cat /etc/version)"

	[ "$old_version" = "$new_version" ] && return 0
	[ -z "$old_version" ] && old_version="$new_version"

	local old_major=$(echo "$old_version" | awk -F . '{ print $2 }')
	local old_minor=$(echo "$old_version" | awk -F . '{ print $3 }')

	rm -rf ${top_dir}/linux

	# do not execute legacy scripts when coming from 7.x
	[ "$old_major" -ge 7 ] && rm -rf ${top_dir}/001_rut*

	# do not execute old scripts when coming from 8.x
	[ "$old_major" -gt 7 ] && rm -rf ${top_dir}/old

	# do not execute old scripts when coming from 7.4.x
	[ "$old_major" -eq 7 ] && [ "$old_minor" -ge 4 ] && rm -rf ${top_dir}/old

	#for legacy rut9/rut2 migration
	is_legacy_profile "$apply_dir" && {
		touch "$apply_dir/etc/config/teltonika"
		cp -af /rom/etc/migrate.conf/* "$apply_dir/etc/migrate.conf/"
	}

	export UCI_CONFIG_DIR="$apply_dir/etc/config"

	mkdir -p "/tmp/.uci"

	find "$top_dir" -maxdepth 1 -type d | sort -V | while read -r dir; do
		[ "$dir" == "$top_dir" ] && continue
		__check_compatibility "$old_major" "$old_minor" "$(basename "$dir")" || continue
		__apply_defaults "$dir"
	done
	__apply_defaults "$top_dir"

	uci_commit

	rm -rf "$top_dir/"
	rm -f $apply_dir/etc/migrate.conf/*
}

call_config_event() {
	/bin/ubus call service event "{ \"type\": \"config.change\", \"data\": { \"package\": \"$1\" }}"
}

apply_config() {
	[ "$RELOAD_EVENT" -eq 1 ] || return 0

	local md5file="${1:-/var/run/config.md5}"

	[ -f "$md5file" ] && {
		local network=0

		for c in $(diff "$md5file"); do
			[ "$c" = "network" ] && {
				network=1
				continue
			}
			call_config_event "$c"
		done

		/bin/ubus -t 180 call mobifd reload >/dev/null
		[ "$network" -eq 1 ] && call_config_event "network"
	}

	find /etc/config -type f ! -name 'profiles' -exec md5sum {} + >"$md5file"
	return 0
}

change_config() {
	local md5file="/var/run/config.md5"
	local new="$1"

	uci_get "profiles" "$new" || {
		log "Profile '$new' not found"
		return 1
	}

	local archive="${MAIN_PATH}$(uci_get profiles $name archive)"
	[ -f "$archive" ] || {
		log "Unable to retrieve profile '$new' archive name"
		return 1
	}

	[ ! -r "$archive" ] && {
		log "Unable to read '$archive'"
		return 1
	}

	rm -f "$md5file"
	apply_config "$md5file"

	mkdir -p "$TMP_PATH"
	tar xzf "$archive" -C "$TMP_PATH" 2>&- || {
		log "Unable to extract '$archive'"
		return 1
	}

	cmp -s "${TMP_PATH}${PROFILE_VERSION_FILE}" /etc/version || {
		# Legacy profiles do not have some config files so we need to reset
		# these files before applying profile
		for file in $KNOWN_CLEANS; do
			cp -af "/rom$file" "$file"
		done
	}

	# Fixing legacy profiles
	remove_exceptions_from_file "$TMP_PATH"

	rm -f "$PROFILE_VERSION_FILE"
	cp -af "$TMP_PATH"/* /
	# Restore all permissions since tar doesn't preserve directory permissions
	/sbin/perm -a 2> /dev/null

	rm -rf "$TMP_PATH"
	uci_set "profiles" "general" "profile" "$new" || {
		log "Unable to set new profile via uci"
		return 1
	}

	uci_commit "profiles" || {
		log "Unable to commit new profile changes via uci"
		return 1
	}

	(
		__uci_apply_defaults
		apply_config "$md5file"
		/bin/ubus send vuci.notify '{"event":"profile_changed"}'
	) &
	return 0
}

diff() {
	local md5file="$1"

	[ -z "$md5file" ] && return 1

	for c in $(md5sum -c "$md5file" 2>/dev/null | sed -nE -e 's/(.*):\s+FAILED/\1/p'); do
		echo "${c##*/}" # for known input (in this case regular fullpath filenames) it's equivalent to basename, but faster
	done

	return 0
}

rm_conffiles() {
	add_uci_conffiles "$RM_CONFFILES"
	# Do not save these configs
	remove_exceptions "$RM_CONFFILES"

	# shellcheck disable=2046 # Splitting is intended here
	rm $(cat $RM_CONFFILES)
}

handle_profile_list() {
	local config="$1"

	config_get updated "$config" updated

	[ $LIST_COUNT -gt 0 ] && {
		echo ","
	}

	echo "{"
	echo "\"name\": \"$config\","
	echo "\"updated\": $updated,"

	if [ "$config" = "$CURRENT_PROFILE" ]; then
		echo "\"active\": 1"
	else
		echo "\"active\": 0"
	fi
	echo "}"

	LIST_COUNT=$((LIST_COUNT + 1))
}

check_profile_exists() {
	local config="$1"
	local new_name="$2"

	[ "$config" = "$new_name" ] && {
		echo "{\"status\": 1, \"error\": \"profile '$new_name' already exists\"}"
		exit 1
	}

	local id
	config_get id "$config" id 0

	local next_id=$((id + 1))
	[ $next_id -gt $NEXT_PROFILE_ID ] && NEXT_PROFILE_ID=$next_id
}

check_name() {
	local name="$1"
	local length=$(echo -n "$name" | wc -m)

	[ $length -lt 1 ] && {
		echo '{"status": 22, "error": "no argument provided"}'
		exit 1
	}

	# check name len
	# limit set to be the same as-is in the webUI.
	[ $length -gt 20 ] && {
		echo '{"status": 22, "error": "given profile name too long (limit: 20 characters)"}'
		exit 1
	}

	# Sanitize input
	local sanitized=$(echo $name | sed 's/ /_/g; s/[^a-zA-Z0-9_]//g')

	# Breaks if name is invalid.
	# better to inform the user of their mistake, rather
	# than contiuing on after making changes to user input,
	# since this ubus object will likely only be called from
	# other scripts/programs
	[ "$sanitized" != "$name" ] && {
		echo '{"status": 22, "error": "invalid profile name"}'
		exit 1
	}
}

# Checks if a name matches the reserved names in /etc/profiles
check_default() {
	local name="$1"

	# Check if names won't interfere with the default profile files in /etc/profiles
	[ "$name" = "default" ] || [ "$name" = "template" ] && {
		echo '{"status": 22, "error": "profile name cannot be '\''template'\'' or '\''default'\''"}'
		exit 1
	}
}

call_handle_create() {
	local name="$1"
	local options="$2"

	# Skip validation if option -s is passed
	[ "$options" = "-s" ] || {
		check_name "$name"
		check_default "$name"
	}

	config_load profiles

	NEXT_PROFILE_ID=0
	config_foreach check_profile_exists profile "$name"

	local now="$(date +%s)"
	local archive="${name}_${now}.tar.gz"
	local md5file="${name}_${now}.md5"

	[ "$name" = "default" ] || [ "$name" = "template" ] && {
		archive="${name}.tar.gz"
		md5file="${name}.md5"
	}

	[ "$name" = "default" ] && NEXT_PROFILE_ID=0

	# Create new config in uci
	uci_add profiles profile "$name"
	uci_set profiles "$name" id "$NEXT_PROFILE_ID"
	uci_set profiles "$name" updated "$now"
	uci_set profiles "$name" archive "$archive"
	uci_set profiles "$name" md5file "$md5file"

	uci_commit profiles

	# Create profile from template if option -t is passed
	[ "$options" = "-t" ] && {
		local template_archive="${MAIN_PATH}template.tar.gz"
		local template_md5file="${MAIN_PATH}template.md5"

		[ -f "$template_archive" ] || {
			echo '{"status": 3, "error": "template not found"}'
			exit 1
		}

		cp -af "$template_archive" "${MAIN_PATH}${archive}"
		cp -af "$template_md5file" "${MAIN_PATH}${md5file}"

		echo '{ "status": 0, "id": '"$NEXT_PROFILE_ID"', "updated": '"$now"', "archive": "'"$archive"'", "md5file": "'"$md5file"'" }'
		exit 0
	}

	do_save_conffiles "${MAIN_PATH}${archive}"
	create_md5 "${MAIN_PATH}${md5file}"

	uci commit

	echo '{ "status": 0, "id": '"$NEXT_PROFILE_ID"', "updated": '"$now"', "archive": "'"$archive"'", "md5file": "'"$md5file"'" }'
}

call_handle_update() {
	local options="$1"

	local prof_archive="${MAIN_PATH}/$(uci_get profiles "$CURRENT_PROFILE" archive)"
	local prof_md5="${MAIN_PATH}/$(uci_get profiles "$CURRENT_PROFILE" md5file)"

	[ -f "$prof_archive" ] || {
		echo '{ "status": 3, "error": "error updating current profile"}'
		exit 1
	}

	rm -f "$prof_archive"
	[ -f "$prof_md5" ] && rm -f "$prof_md5"

	local now="$(date +%s)"

	config_load profiles
	uci_set profiles "$CURRENT_PROFILE" updated "$now"
	uci_commit profiles

	do_save_conffiles "$prof_archive"
	create_md5 "$prof_md5"

	[ -f "$prof_archive" ] || {
		echo '{ "status": 3, "error": "error updating current profile"}'
		exit 1
	}

	[ "$options" = "-q" ] || echo '{ "status": 0 }'
}

call_handle_change() {
	local name="$1"
	local options="$2"

	check_name "$name"

	local scheduler="$(uci_get profiles general enabled "0")"
	[ "$options" != "-f" ] && [ "$scheduler" = "1" ] && {
		echo '{ "status": 1, "error": "can not change profile, scheduler is enabled"}'
		exit 1
	}

	call_handle_update -q

	local archive="$(uci_get profiles $name archive)"
	if [ -n "$archive" ]; then
		change_config "$name" &>/dev/null || {
			echo '{ "status": 4, "error": "error changing profile"}'
			exit 1
		}
		echo '{ "status": 0 }'
	else
		echo '{ "status": 2, "error": "profile not found"}'
		exit 1
	fi
}

call_handle_remove() {
	local name="$1"

	config_load profiles

	check_name "$name"
	check_default "$name"

	local archive_path="${MAIN_PATH}$(uci_get profiles $name archive \".\")"
	local md5file_path="${MAIN_PATH}$(uci_get profiles $name md5file \".\")"

	local err_chk=0
	[ -f "$archive_path" ] && rm -f "$archive_path" || err_chk=1
	[ -f "$md5file_path" ] && rm -f "$md5file_path" || err_chk=1

	[ $err_chk -eq 1 ] && {
		echo '{"status": 5, "error": "encountered errors while removing profile"}'
		exit 1
	}

	uci_remove profiles "$name"

	# profile currently in use is being removed,
	# reset to default.
	[ "$name" = "$CURRENT_PROFILE" ] && {
		change_config "default" &>/dev/null
	}

	uci_commit profiles
	uci commit

	echo '{ "status": 0 }'
}

call_handle_list() {
	LIST_COUNT=0

	echo '{ "profiles": ['
	config_load profiles
	config_foreach handle_profile_list profile
	echo ']}'
}

call_handle_diff() {
	local name="$1"

	check_name "$name"

	local md5file_path="${MAIN_PATH}$(uci_get profiles $name md5file \".\")"
	[ -f "$md5file_path" ] || {
		echo '{"status": 2, "error": "could not find profile"}'
		exit 1
	}

	echo '{ "status": 0, "diff": ['
	diff "${MAIN_PATH}${name}"*.md5 | sed 's/^/\"/; s/$/\",/'
	echo ']}'
}

# Print usage information
print_usage() {
	cat <<EOF
Usage: $0 [OPTIONS]
Options:
  -b NAME      Create a new profile with NAME
  -c NAME      Change to profile NAME
  -u           Update current profile
  -d NAME      Show diff for profile NAME
  -r NAME      Remove profile NAME
  -l           List all profiles
  -f           Fix configs
  -a TYPE      Apply defaults
  -i FILE      Install package
  -p FILE      Remove package
  -s           Skip validation (with -b)
  -t           Create profile from template (with -b)
  -h           Show this help message
EOF
	exit 1
}

# Initialize variables for flags
b_flag=0
c_flag=0
u_flag=0
d_flag=0
r_flag=0
l_flag=0
f_flag=0
a_flag=0
i_flag=0
p_flag=0
s_flag=0
t_flag=0
h_flag=0
n_flag=0

b_arg=""
c_arg=""
d_arg=""
r_arg=""
a_arg=""
i_arg=""
p_arg=""

if [ $# -eq 0 ]; then
	print_usage
fi

while getopts "b:c:ud:r:lfa:i:p:sthn" opt; do
	case $opt in
		b)
			b_flag=1
			b_arg="$OPTARG"
			;;
		c)
			c_flag=1
			c_arg="$OPTARG"
			;;
		u)
			u_flag=1
			;;
		d)
			d_flag=1
			d_arg="$OPTARG"
			;;
		r)
			r_flag=1
			r_arg="$OPTARG"
			;;
		l)
			l_flag=1
			;;
		f)
			f_flag=1
			;;
		a)
			a_flag=1
			a_arg="$OPTARG"
			;;
		i)
			i_flag=1
			i_arg="$OPTARG"
			;;
		p)
			p_flag=1
			p_arg="$OPTARG"
			;;
		s)
			s_flag=1
			;;
		t)
			t_flag=1
			;;
		h)
			h_flag=1
			;;
		n)
			n_flag=1
			;;
		\?)
			log "Invalid option: -$OPTARG"
			print_usage
			;;
		:)
			log "Option -$OPTARG requires an argument."
			print_usage
			;;
	esac
done

if [ $h_flag -eq 1 ]; then
	print_usage
fi

if [ $n_flag -eq 1 ]; then
	RELOAD_EVENT=0
fi

if [ $a_flag -eq 1 ]; then
	apply_defaults "$a_arg"
fi

if [ $b_flag -eq 1 ]; then
	option=""
	[ $s_flag -eq 1 ] && option="-s"
	[ $t_flag -eq 1 ] && option="-t"
	call_handle_create "$b_arg" "$option"
fi

if [ $c_flag -eq 1 ]; then
	option=""
	[ $f_flag -eq 1 ] && option="-f"
	call_handle_change "$c_arg" "$option"
fi

if [ $u_flag -eq 1 ]; then
	call_handle_update
fi

if [ $d_flag -eq 1 ]; then
	call_handle_diff "$d_arg"
fi

if [ $r_flag -eq 1 ]; then
	call_handle_remove "$r_arg"
fi

if [ $l_flag -eq 1 ]; then
	call_handle_list
fi

if [ $f_flag -eq 1 ] && [ $c_flag -eq 0 ]; then
	fix_configs
fi

if [ $i_flag -eq 1 ]; then
	install_pkg "$i_arg"
fi

if [ $p_flag -eq 1 ]; then
	remove_pkg "$p_arg"
fi

exit $?
