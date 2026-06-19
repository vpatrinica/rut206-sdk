#
# Copyright (C) 2025 Teltonika
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/download.mk

PKG_NAME:=inetd-ubus
PKG_VERSION:=2026-04-07
PKG_SOURCE_VERSION:=7.22
PKG_LICENSE:=Teltonika-closed

include $(INCLUDE_DIR)/package.mk

define Package/inetd-ubus
	SECTION:=net
	CATEGORY:=Network
	TITLE:=inetd-like daemon which supports managing connections through ubus.
	DEPENDS:=+libtlt-logger +libubus +libcap
	FATTRS:=/usr/bin/inetd-ubus::::cap_net_bind_service=ep
endef


define Package/inetd-ubus/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/inetd-ubus $(1)/usr/bin/inetd-ubus
endef

$(eval $(call BuildPackage,inetd-ubus))
