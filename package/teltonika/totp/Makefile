#
# Copyright (C) 2026 Teltonika
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/download.mk

PKG_NAME:=totp
PKG_VERSION:=2026-04-07
PKG_RELEASE:=1

PKG_SOURCE_VERSION:=1.0
PKG_LICENSE:=Teltonika-closed

include $(INCLUDE_DIR)/package.mk

define Package/totp/description
	This application provides TOTP utility methods through ubus
endef

define Package/totp
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=TOTP rpcd module
  DEPENDS:=+rpcd +libcotp +libopenssl +libuci +libubox +libubus
  USERID:=totp=657:totp=657
endef


define Package/totp/install
	$(INSTALL_DIR) $(1)/usr/lib/rpcd $(1)/etc/config $(1)/etc/permtab.d 
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/totp.so $(1)/usr/lib/rpcd/
	$(INSTALL_CONF_USR) $(PKG_BUILD_DIR)/files/totp.config $(1)/etc/config/totp
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/files/totp.permtab $(1)/etc/permtab.d/totp

	$(INSTALL_DIR) $(1)/etc/uci-defaults/7.23
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/files/uci-default/7.23/99_add_totp_users $(1)/etc/uci-defaults/7.23/
endef

$(eval $(call BuildPackage,totp))
