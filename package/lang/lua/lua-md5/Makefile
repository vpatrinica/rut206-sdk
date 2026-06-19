#
# Copyright (C) 2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=lua-md5
PKG_VERSION:=1.3
PKG_RELEASE:=1
PKG_MAINTAINER:=Dirk Chang <dirk@kooiot.com>
PKG_LICENSE:=MIT
PKG_LICENSE_FILE:=doc/us/license.html

PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)

PKG_SOURCE_URL:=https://github.com/lunarmodules/md5.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=1.3

PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

define Package/lua-md5
  SUBMENU:=Lua
  SECTION:=lang
  CATEGORY:=Languages
  TITLE:=Lua-MD5
  URL:=https://github.com/keplerproject/md5
  DEPENDS:=+luajit2
endef

define Package/lua-md5/description
  MD5 offers basic cryptographic facilities for Lua
endef

TARGET_CFLAGS += $(FPIC)
TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include/luajit-2.1
MAKE_FLAGS += LIB_OPTION="-shared"

define Build/Configure
endef

define Build/Compile
	$(call Build/Compile/Default,all)
endef

define Build/Install
endef

define Package/lua-md5/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/md5.lua $(1)/usr/lib/lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/md5
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/core.so $(1)/usr/lib/lua/md5/core.so
endef

$(eval $(call BuildPackage,lua-md5))
