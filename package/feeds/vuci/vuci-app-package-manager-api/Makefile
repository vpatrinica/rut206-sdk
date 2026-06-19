include $(TOPDIR)/rules.mk

APP_TITLE:=VuCI API Support for Package Manager

# when @ is used, pkg name must be full (like in .config file - PACKAGE_*).
# curl and pkg manager is not available on tswos. @ works better with warnings (doesn't display them) when both packages aren't selected
APP_DEPENDS:=+@PACKAGE_curl
CUSTOM_INSTALL=1

include ../api.mk


define Package/$(PKG_NAME)/install
	$(call Package/$(PKG_NAME)/install/Default,$(1))
	$(INSTALL_DIR) $(1)/usr/lib/lua/vuci
	$(CP) ./distro/opkg-wrt.lua $(1)/usr/lib/lua/vuci/opkg_utils.lua
endef

# call BuildPackage - OpenWrt buildroot signature
$(eval $(call BuildPackage,$(PKG_NAME)))
