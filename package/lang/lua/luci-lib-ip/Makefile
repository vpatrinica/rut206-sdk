include $(TOPDIR)/rules.mk

PKG_NAME:=luci-lib-ip

PKG_VERSION:=2026-04-07


PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

TARGET_CFLAGS += $(FPIC)
TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include/luajit-2.1

define Package/luci-lib-ip
	SECTION:=libs
	CATEGORY:=Libraries
	TITLE:=Lua library for IP calculation and routing information
	DEPENDS:=+luajit2 +libnl-tiny
endef

define Package/luci-lib-ip/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ip.so $(1)/usr/lib/lua/luci/
endef

$(eval $(call BuildPackage,luci-lib-ip))
