#
# Copyright (C) 2024 Teltonika
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/download.mk

PKG_NAME:=libuacl
PKG_SOURCE_VERSION:=1.1
PKG_SOURCE_DATE:=2025-12-10

PKG_LICENSE:=Teltonika-closed
GPL_INCLUDE_HEADERS:=1

include $(INCLUDE_DIR)/package.mk

MAKE_FLAGS += FPIC="$(FPIC)"

define Package/libuacl
	SECTION:=libs
	CATEGORY:=Libraries
	TITLE:=RUTOS ACL library
	DEPENDS:=+libblobmsg-json
endef

define Package/libuacl/description
	A helper library for RUTOS ACL (Access Control List) management.
	It provides an easy way to grant access to a system resources
endef


define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/libuacl.so* $(1)/usr/lib/
	$(CP) $(PKG_BUILD_DIR)/include/libuacl.h $(1)/usr/include/
endef

define Package/libuacl/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/libuacl.so $(1)/usr/lib/libuacl.so
endef

$(eval $(call BuildPackage,libuacl))
