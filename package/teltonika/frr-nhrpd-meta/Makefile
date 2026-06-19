include $(TOPDIR)/rules.mk

PKG_NAME:=frr-nhrpd-meta
PKG_VERSION:=2026-01-21
PKG_RELEASE:=1
PKG_LICENSE:=Teltonika-closed

include $(INCLUDE_DIR)/package.mk

define Package/frr-nhrpd-meta
	SECTION:=net
	CATEGORY:=Network
	TITLE:=FRR nhrpd service meta package
	DEPENDS:=+vuci-app-dynamic-routes-nhrp-ui
	ifneq (,$(filter m,$(CONFIG_PACKAGE_frr-nhrpd-meta))$(DUMP))
		PKG_TLT_NAME:=NHRP daemon
		PKG_ROUTER:=$(TLT_PLATFORM_NAME)
		PKG_APP_NAME:=frr-nhrp
	endif
endef

define Package/frr-nhrpd-meta/description
	Next Hop Resolution Protocol (NHRP) is a protocol or method that can
	be used so that a computer sending data to another computer can learn
	the most direct route (the fewest number of hops) to the receiving computer.
endef



define Package/frr-nhrpd-meta/install
	$(INSTALL_DIR) $(1)/usr/share/vuci/menu.d/
	$(LN) /usr/local/usr/share/vuci/menu.d/routes_nhrp.json $(1)/usr/share/vuci/menu.d/routes_nhrp_link.json
endef

$(eval $(call BuildPackage,frr-nhrpd-meta))
