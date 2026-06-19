include $(TOPDIR)/rules.mk

PKG_NAME:=ldpd-frr-meta
PKG_VERSION:=2026-01-21
PKG_RELEASE:=1
PKG_LICENSE:=Teltonika-closed

include $(INCLUDE_DIR)/package.mk

define Package/ldpd-frr-meta
	SECTION:=net
	CATEGORY:=Network
	TITLE:=MPLS-ui service meta package
	DEPENDS:=+vuci-app-mpls-ui
	ifneq (,$(filter m,$(CONFIG_PACKAGE_ldpd-frr-meta))$(DUMP))
		PKG_TLT_NAME:=MPLS
		PKG_ROUTER:=$(TLT_PLATFORM_NAME)
		PKG_APP_NAME:=mpls
	endif
endef

define Package/ldpd-frr-meta/description
	Multiprotocol Label Switching (MPLS) is a routing technique that uses labels instead of network addresses for routing decisions 
endef



define Package/ldpd-frr-meta/install
	$(INSTALL_DIR) $(1)/usr/share/vuci/menu.d/
	$(LN) /usr/local/usr/share/vuci/menu.d/mpls.json $(1)/usr/share/vuci/menu.d/mpls_link.json
endef

$(eval $(call BuildPackage,ldpd-frr-meta))
