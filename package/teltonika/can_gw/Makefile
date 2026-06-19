include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/download.mk

PKG_NAME:=can_gw
PKG_VERSION:=2026-04-09
PKG_SOURCE_VERSION:=7.23
PKG_LICENSE:=Teltonika-closed

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=net
	CATEGORY:=Network
	TITLE:=can_gw enables CAN frame transfer over IP network
	DEPENDS:=+libubox +libuci +libtlt_uci +libubus +libpthread \
		 +libopenssl +@OPENSSL_WITH_DTLS +libboardjson +libnl +libnl-genl +libnl-route
	FATTRS:=/usr/sbin/can_gw::::cap_net_bind_service,cap_net_admin=ep
	USERID:=can_gw=648:can_gw=648
endef

define Package/$(PKG_NAME)/description
	can_gw enables CAN frame transfer over IP network
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/can_gw
endef


define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/etc/init.d $(1)/etc/config $(1)/etc/permtab.d $(1)/usr/share/acl.d $(1)/etc/uci-defaults/etc $(1)/etc/uci-defaults/7.14
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/can_gw $(1)/usr/sbin/can_gw
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/files/can_gw.init $(1)/etc/init.d/can_gw
	$(INSTALL_CONF_USR) $(PKG_BUILD_DIR)/files/can_gw.conf $(1)/etc/config/can_gw
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/files/can_gw.json $(1)/usr/share/acl.d/can_gw.json
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/files/can_gw.permtab $(1)/etc/permtab.d/can_gw
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
