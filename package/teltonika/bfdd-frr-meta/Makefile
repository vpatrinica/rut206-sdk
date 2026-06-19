include $(TOPDIR)/rules.mk

PKG_NAME:=bfdd-frr-meta
PKG_VERSION:=2026-01-21
PKG_RELEASE:=1
PKG_LICENSE:=Teltonika-closed

include $(INCLUDE_DIR)/package.mk

define Package/bfdd-frr-meta
	SECTION:=net
	CATEGORY:=Network
	TITLE:=BFD-ui service meta package
	DEPENDS:=+vuci-app-bfd-ui
	ifneq (,$(filter m,$(CONFIG_PACKAGE_bfdd-frr-meta))$(DUMP))
		PKG_TLT_NAME:=BFD
		PKG_ROUTER:=$(TLT_PLATFORM_NAME)
		PKG_APP_NAME:=bfdd-frr
	endif
endef

define Package/bfdd-frr-meta/description
	Protocol intended to detect faults in the bidirectional path between two forwarding engines, including interfaces, data link(s), and to the extent possible the forwarding engines themselves, with potentially very low latency.
endef



define Package/bfdd-frr-meta/install
	$(INSTALL_DIR) $(1)/usr/share/vuci/menu.d/
	$(LN) /usr/local/usr/share/vuci/menu.d/bfd.json $(1)/usr/share/vuci/menu.d/bfd_link.json
endef

$(eval $(call BuildPackage,bfdd-frr-meta))
