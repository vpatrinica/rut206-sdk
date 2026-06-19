include $(TOPDIR)/rules.mk

PKG_NAME:=luci-lib-nixio

PKG_VERSION:=2026-04-07


PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

TARGET_CFLAGS += $(FPIC)
TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include/luajit-2.1

define Package/luci-lib-nixio
	SECTION:=libs
	CATEGORY:=Libraries
	TITLE:=NIXIO POSIX library
	DEPENDS:=+luajit2
endef

define Package/luci-lib-nixio/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/nixio.so $(1)/usr/lib/lua/

	$(INSTALL_DIR) $(1)/usr/lib/lua/nixio/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/lua/fs.lua $(1)/usr/lib/lua/nixio/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/lua/util.lua $(1)/usr/lib/lua/nixio/

	$(INSTALL_DIR) $(1)/lib/upgrade/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/files/luci-add-conffiles.sh $(1)/lib/upgrade/
endef

$(eval $(call BuildPackage,luci-lib-nixio))
