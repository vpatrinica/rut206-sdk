include $(TOPDIR)/rules.mk

PKG_NAME:=frr-eigrpd-meta
PKG_VERSION:=2026-01-21
PKG_RELEASE:=1
PKG_LICENSE:=Teltonika-closed

include $(INCLUDE_DIR)/package.mk

define Package/frr-eigrpd-meta
	SECTION:=net
	CATEGORY:=Network
	TITLE:=FRR eigrpd service meta package
	DEPENDS:=+vuci-app-dynamic-routes-eigrp-ui
	ifneq (,$(filter m,$(CONFIG_PACKAGE_frr-eigrpd-meta))$(DUMP))
		PKG_TLT_NAME:=EIGRP daemon
		PKG_ROUTER:=$(TLT_PLATFORM_NAME)
		PKG_APP_NAME:=frr-eigrpd
	endif
endef

define Package/frr-eigrpd-meta/description
	Enhanced Interior Gateway Routing Protocol (EIGRP) is an
	advanced distance-vector routing protocol that is used on a
	computer network for automating routing decisions and configuration.
endef



define Package/frr-eigrpd-meta/install
	$(INSTALL_DIR) $(1)/usr/share/vuci/menu.d/
	$(LN) /usr/local/usr/share/vuci/menu.d/routes_eigrp.json $(1)/usr/share/vuci/menu.d/routes_eigrp_link.json
endef

$(eval $(call BuildPackage,frr-eigrpd-meta))
