include $(TOPDIR)/rules.mk

PKG_NAME:=dmvpn-meta
PKG_VERSION:=2026-01-21
PKG_RELEASE:=1
PKG_LICENSE:=Teltonika-closed

include $(INCLUDE_DIR)/package.mk

define Package/dmvpn-meta
	SECTION:=net
	CATEGORY:=Network
	TITLE:=DMVPN service meta package
	DEPENDS:=+vuci-app-dmvpn-ui
	ifneq (,$(filter m,$(CONFIG_PACKAGE_dmvpn-meta))$(DUMP))
		PKG_TLT_NAME:=DMVPN
		PKG_ROUTER:=$(TLT_PLATFORM_NAME)
		PKG_APP_NAME:=dmvpn
	endif
endef

define Package/dmvpn-meta/description
	Dynamic Multipoint VPN (DMVPN) is a method of building scalable IPsec VPNs.
	DMVPN is configured as a hub-and-spoke network, where tunnels between spokes
	are built dynamically; therefore, no change in configuration is required on
	the hub in order to connect new spokes.
endef



define Package/dmvpn-meta/install
	$(INSTALL_DIR) $(1)/usr/share/vuci/menu.d/
	$(LN) /usr/local/usr/share/vuci/menu.d/dmvpn.json $(1)/usr/share/vuci/menu.d/dmvpn_link.json
endef

$(eval $(call BuildPackage,dmvpn-meta))
