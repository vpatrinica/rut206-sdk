#!/bin/sh

. /usr/share/libubox/jshn.sh
ULOGD_DIR="/usr/local/home/ulogd"
SSH_DIR="${ULOGD_DIR}/.ssh"
KEY_FILE="${SSH_DIR}/id_rsa"
PUB_FILE="${KEY_FILE}.pub"

set_key_perms() {
	chown ulogd:ulogd "$KEY_FILE"
	chown ulogd:ulogd "$PUB_FILE"
	chmod 600 "$KEY_FILE"
	chmod 644 "$PUB_FILE"
}

generate_key() {
	local code err_msg

	rm -f "$KEY_FILE"
	rm -f "$PUB_FILE"
	err_msg=$(dropbearkey -t rsa -s 2048 -f "$KEY_FILE" 2>&1 >/dev/null)
	code=$?
	[ $code -ne 0 ] && {
		echo "{\"err_msg\":\"$err_msg\",\"code\":$code}"
		return $code
	}

	set_key_perms
	echo "{\"pubkey\":\"$(cat "$PUB_FILE")\",\"code\":0}"
}

upload_key() {
	local tmpfile pubkey

	tmpfile="$1"
	pubkey=$(dropbearkey -y -f "$tmpfile" | grep ^ssh-)
	[ "$pubkey" = "" ] && {
		rm -f "$tmpfile"
		echo '{"err_msg":"Invalid key","code":1}'
		return 1
	}

	rm -f "$KEY_FILE"
	rm -f "$PUB_FILE"
	mv "$tmpfile" "$KEY_FILE"
	echo "$pubkey" > "$PUB_FILE"
	set_key_perms
	echo "{\"pubkey\":\"$pubkey\",\"code\":0}"
}

main() {
	case "$1" in
		list)
			echo '{ "generate_key": {}, "upload_key": { "privkey": "str" } }'
			;;
		call)
			case "$2" in
				generate_key)
					generate_key
					;;
				upload_key)
					read input
					json_load "$input"
					json_get_var privkey "privkey"
					upload_key "$privkey"
					;;
			esac
		;;
	esac
}

main "$@"
