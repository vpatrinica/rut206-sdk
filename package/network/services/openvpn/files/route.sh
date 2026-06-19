#!/bin/sh


operation="$1" # add, update, delete
address="$2" # the address being learned or unlearned
cname="$3" # the common name on the certificate associated with the client linked to this address

case "$address" in
	*:*) t=" -6"; six="6" ;;
	*)   t=""; six="" ;;
esac

case "$operation" in
	add)    op="add" ;;
	update) op="replace" ;;
	delete) op="del" ;;
esac

gw_var="ifconfig_pool_remote_ip${six}"
eval "gw=\${$gw_var}"
if [ -n "$gw" ] && [ "$address" != "$gw" ]; then
	via="via $gw"
else
	via=""
fi
[ -n "$dev" ] && device="dev $dev" || device=""
[ -n "$cname" ] && name="${cname}/route" || name="route"
if [ -n "$config" ]; then
	instance="${config%%.conf*}"
	instance="${instance##*/openvpn-}"
fi

if ip${t} route $op "$address" $via $device; then
	[ -n "$instance" ] && logger -p daemon.notice -t "openvpn@${instance}" "$name $op $address $via" \
		|| logger -p daemon.notice -t "openvpn" "route $op $address $via"
fi

exit 0
