#!/usr/bin/env bash

days=''
PACKAGES_ROOT=/home/admin/opkg_packages
URL_VARIANT=
TOPDIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")

help_and_exit() {
	printf "Usage: upload_opkg.sh [-c [DAYS]] [--show-url [VARIANT]] { -d | -p } DEVICE

Options:
	-c | --cleanup DAYS	Cleanup packages that are older than DAYS (default: 15).
					DEVICE argument is not required, all devices will be cleaned up.
	-d | --demo		Upload to OPKG test server
	-p | --production	Upload to OPKG production server
	--show-url [VARIANT]	Print the OPKG URL and exit (VARIANT defaults to 'teltonika';
					use '3rd_party' for the third-party URL)

Arguments:
	DEVICE			Target name, e.g. RUT36

SSH credentials that are needed in the environment:
	{PRODUCTION | TEST}_SSH_PRIVATE_KEY
	{PRODUCTION | TEST}_SSH_HOST_KEY
	{PRODUCTION | TEST}_SSH_USER_HOST
	{PRODUCTION | TEST}_SSH_PORT
"
	exit 1
}

check_missing() {
	for var in "${SSH_PRIVATE_KEY}" "${SSH_HOST_KEY}" "${SSH_USER_HOST}" "${SSH_PORT}"; do
		[[ -z ${!var} ]] && echo "$var"
	done
}

cleanup() {
	local path=${1}/
	local mtime=+${2:-15}

	local df_cmd="df --block-size=1 --output=used '$path' | tail -n1"
	local fmt='%7d MB'

	ssh -p "${!SSH_PORT}" "${!SSH_USER_HOST}" "\
		b=\"\$($df_cmd)\" ;\
		d=1048576 ;\
		find '$path' -mindepth 3 -maxdepth 3 ! -path 'opkg_packages/packages/*' -type d -mtime '$mtime' -print -exec rm -r {} + ;\
		find '$path' -name wiki -type d -exec rm -rf {} + ;\
		a=\"\$($df_cmd)\" ;\
		printf \"Before:  $fmt\\nAfter:   $fmt\\nCleaned: $fmt\\n\" \"\$((b / d))\" \"\$((a / d))\" \"\$(((b - a) / d))\"
	"
}

while [ $# -gt 0 ]; do
	case $1 in
	--cleanup | -c)
		days=$2
		[[ $days -lt 1 ]] && days=
		shift 1
		;;
	--production | -p)
		prefix=PRODUCTION
		;;
	--demo | -d)
		prefix=TEST
		;;
	--show-url)
		URL_VARIANT=${2:-teltonika}
		;;
	-*)
		help_and_exit
		;;
	*)
		PLATFORM="${1^^}"
		;;
	esac
	shift 1
done

[[ -z $prefix ]] && help_and_exit

show_url() {
	local prefix=$1
	# shellcheck disable=SC2155
	local variant=$(echo "$2" | grep -o '3rd_party')

	local version=$TLT_VERSION
	[[ -z $version ]] && version=$("$TOPDIR/scripts/get_tlt_version.sh")

	local short_version=${CI_COMMIT_TAG:-$FW_TAG}
	[[ -z $short_version ]] && short_version=$("$TOPDIR/scripts/get_tlt_version.sh" --short)

	# shellcheck disable=SC2155
	local client=$(echo "$version" | grep -Po '_\K\d+(?=\.)')
	[[ -z $client ]] && client=$(grep 'CONFIG_TLT_VERSIONING_CLIENT' .config | cut -d'=' -f2 | tr -d '"')
	# shellcheck disable=SC2155
	local fw_type=$(echo "$version" | grep -Po ".+_[^\d]+(?=\d*_${client})")
	local target=$PLATFORM

	case "$prefix" in
	PRODUCTION)
		local hash_input="${client}/${short_version}/${target}${variant:+-$variant}"
		echo "$hash_input" >&2 # debug
		echo "https://opkg.teltonika-networks.com/$(echo -n "$hash_input" | sha256sum | awk '{print $1}')"
		;;
	TEST)
		echo "https://test.opkg.teltonika-networks.com/$client/$fw_type/$version/packages${variant:+-$variant}"
		;;
	esac
}

if [[ -n $URL_VARIANT ]]; then
	show_url "$prefix" "$URL_VARIANT"
	exit $?
fi

[[ -d ${TOPDIR}/bin/packages ]] || {
	echo "No packages found"
	exit 0
}

upload_to_local_server() {
	local server_path=${1//"http://${CACHE_SERVER_HOST}/"/"http://${CACHE_SERVER_HOST}/upload/"}
	local opkg_dir=$2

	find "${TOPDIR}/bin/packages/" -type d -name "$opkg_dir" | while read -r dir_with_packages; do
		find "$dir_with_packages" -print0 | sed "s,${dir_with_packages}/,,g" | xargs -0 -P 10 -I{} curl -H "$AUTH_HEADER" -X PUT -F file=@"${dir_with_packages}/{}" "${server_path}/{}?overwrite=true"
	done &>"${TOPDIR}/logs/pkg_deploy.log"
}

demo() {
	[[ -n $days && $prefix == TEST ]] && {
		printf "%s cleanup is not implemented yet\n" "$prefix"
		exit 0
	}

	# shellcheck disable=SC2155
	local url=$(show_url "$prefix" "")
	upload_to_local_server "$url" pm_packages
	echo "OPKG URL: $url"

	url=$(show_url "$prefix" "3rd_party")
	upload_to_local_server "$url" pm_packages_third_party
	echo "OPKG 3RD PARTY URL: $url"
}

# [[ $prefix == TEST ]] && {
# 	demo
# 	exit 0
# }

SSH_PRIVATE_KEY="${prefix}_SSH_PRIVATE_KEY"
SSH_HOST_KEY="${prefix}_SSH_HOST_KEY"
SSH_USER_HOST="${prefix}_SSH_USER_HOST"
SSH_PORT="${prefix}_SSH_PORT"

missing=$(check_missing)
[[ -n $missing ]] && {
	#shellcheck disable=2086 # Splitting of 'missing' is intended here
	printf "Environment variable not found: %s\n" $missing
	help_and_exit
}

eval "$(ssh-agent -s)"
trap "ssh-agent -k" exit
ssh-add <(echo "${!SSH_PRIVATE_KEY}")
mkdir -p ~/.ssh
echo "${!SSH_HOST_KEY}" >>~/.ssh/known_hosts

[[ -n $days ]] && {
	[[ $prefix == PRODUCTION ]] && {
		printf "%s cleanup is not allowed!\n" "$prefix"
		exit 1
	}
	cleanup "$PACKAGES_ROOT" "$days"
	exit 0
}

url=$(show_url "$prefix" "")

FOLDER="$PACKAGES_ROOT/${url#*opkg.teltonika-networks.com/}"

short_version=${CI_COMMIT_TAG:-$(git describe | awk -F "-pm" '{print $1}')-$(git -C "$TOPDIR/feeds/vuci" rev-parse --short HEAD)}
client=$(grep 'CONFIG_TLT_VERSIONING_CLIENT' .config | cut -d'=' -f2 | tr -d '"')
LINK="$PACKAGES_ROOT/packages/${client}/${short_version}"

echo "OPKG URL: $url"

echo "UPLOADING TO ${!SSH_USER_HOST#*@}:"
ssh -p "${!SSH_PORT}" "${!SSH_USER_HOST}" "rm -fr '${FOLDER:?}'"
ssh -p "${!SSH_PORT}" "${!SSH_USER_HOST}" "mkdir -p '${FOLDER}' '${LINK}' && ln -fs '${FOLDER}' '${LINK}/${PLATFORM}'" || exit 1
find "${TOPDIR}/bin/packages/" -type d -name pm_packages | while read -r pkg_dir; do
	scp -P "${!SSH_PORT}" "${pkg_dir}"/* "${!SSH_USER_HOST}:/${FOLDER}/" || exit $?
done
