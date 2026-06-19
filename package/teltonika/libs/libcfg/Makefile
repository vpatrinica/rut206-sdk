
#
# Copyright (C) 2024 Teltonika
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/download.mk

PKG_NAME:=libcfg
PKG_SOURCE_VERSION:=1.10
PKG_SOURCE_DATE:=2026-02-12

GPL_INCLUDE_HEADERS:=1

PKG_LICENSE:=Teltonika-closed

include $(INCLUDE_DIR)/package.mk

MAKE_FLAGS += FPIC="$(FPIC)"

define Package/libcfg
	SECTION:=libs
	CATEGORY:=Libraries
	TITLE:=A helper library for UCI config parsing
	DEPENDS:=+libuci +libubus +libubox
endef


define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/libcfg.so* $(1)/usr/lib/
	$(CP) $(PKG_BUILD_DIR)/include/libcfg.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/include/libcfg_uci.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/include/libcfg_ubus.h $(1)/usr/include/
endef

define Package/libcfg/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/libcfg.so $(1)/usr/lib/libcfg.so
endef

$(eval $(call BuildPackage,libcfg))
