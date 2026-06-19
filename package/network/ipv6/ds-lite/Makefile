#
# Copyright (C) 2013 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=ds-lite
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=GPL-2.0
PKG_ORIGIN_URL:=https://github.com/openwrt/openwrt/tree/openwrt-22.03/package/network/ipv6/ds-lite

include $(INCLUDE_DIR)/package.mk

define Package/ds-lite
	SECTION:=net
	CATEGORY:=Network
	DEPENDS:=@IPV6 +kmod-ip6-tunnel +resolveip
	TITLE:=Dual-Stack Lite (DS-Lite) configuration support
	MAINTAINER:=Steven Barth <steven@midlink.org>
	PKGARCH:=all
	ifneq (,$(filter m,$(CONFIG_PACKAGE_ds-lite))$(DUMP))
		PKG_TLT_NAME:=DS-Lite
		PKG_ROUTER:=$(TLT_PLATFORM_NAME)
		PKG_NETWORK_RESTART:=1
	endif
endef

define Package/ds-lite/description
Provides support for Dual-Stack Lite protocol configuration.
endef

define Build/Compile
endef

define Build/Configure
endef

define Package/ds-lite/install
	$(eval DEST_DIR:=$$(1)$(if $(findstring m,$(CONFIG_PACKAGE_ds-lite)),,/usr/local))
	$(INSTALL_DIR) $(DEST_DIR)/usr/lib/netifd/proto/
	$(INSTALL_BIN) ./files/dslite.sh $(DEST_DIR)/usr/lib/netifd/proto/dslite.sh
endef

define Package/ds-lite/prerm
	#!/bin/sh

	[ -z "$${IPKG_INSTROOT}" ] || exit 0
	. /lib/functions.sh

	id_array=""
	get_dslite_ifaces() {
		local proto
		local iface="$$1"
		config_get proto "$$iface" "proto"
		[ "$$proto" = "dslite" ] && {
			[ "$$id_array" = "" ] && id_array="\"$$iface\"" || id_array="$${id_array}, \"$${iface}\""
		}
	}

	config_load "network"
	config_foreach get_dslite_ifaces "interface"

	[ "$$id_array" = "" ] && exit 0

	json_payload='{"data": ['$$id_array']}'

	api delete /interfaces/config "$$json_payload" > /dev/null 2>&1

	exit 0
endef

$(eval $(call BuildPackage,ds-lite))
