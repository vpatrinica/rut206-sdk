#
# Copyright (C) 2009-2013 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luasocket
PKG_SOURCE_DATE:=2019-04-21
PKG_RELEASE:=2
PKG_BUILD_DEPENDS:=VUCI_COMPILE_LUA:luajit2/host

PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=733af884f1aa18ff469bf3c4d18810e815853211
PKG_SOURCE_URL:=https://github.com/diegonehab/luasocket


PKG_MAINTAINER:=W. Michael Petullo <mike@flyn.org>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

LUAJIT_ARGS=-t raw -d
ifeq ($(CONFIG_ARCH_64BIT),y)
	LUAJIT_ARGS += -X
else
	LUAJIT_ARGS += -W
endif

define Package/luasocket/default
  SUBMENU:=Lua
  SECTION:=lang
  CATEGORY:=Languages
  URL:=http://w3.impa.br/~diego/software/luasocket
endef

define Package/luasocket
  $(Package/luasocket/default)
  TITLE:=LuaSocket
  DEPENDS:=+luajit2
  VARIANT:=luajit2
  DEFAULT_VARIANT:=1
endef

define Package/luasocket/default/description
  LuaSocket is the most comprehensive networking support
  library for the Lua language. It provides easy access to
  TCP, UDP, DNS, SMTP, FTP, HTTP, MIME and much more.
endef
Package/luasocket/description     = $(Package/luasocket/default/description)

define Build/Configure
endef

define Build/Compile
	$(if $(CONFIG_VUCI_COMPILE_LUA), \
		$(FIND) $(PKG_BUILD_DIR)/src -type f -name '*.lua' | while read src; do \
			LUA_PATH="$(STAGING_DIR_HOSTPKG)/share/luajit-2.1/?.lua;;" $(STAGING_DIR_HOSTPKG)/bin/luajit -b $(LUAJIT_ARGS) "$$$$src" "$$$$src" ;\
		done; \
	)
	$(MAKE) -C $(PKG_BUILD_DIR)/ \
		LIBDIR="$(TARGET_LDFLAGS)" \
		CC="$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_CPPFLAGS) $(FPIC)" \
		LD="$(TARGET_CROSS)ld -shared" \
		LUAV=jit-2.1 \
		LUAINC_linux_base=$(STAGING_DIR)/usr/include \
		all
endef

define Package/luasocket/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/{ltn12,mime,socket}.lua $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/mime-1.0.3.so $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/socket-3.0-rc1.so $(1)/usr/lib/lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/mime
	ln -sf ../mime-1.0.3.so $(1)/usr/lib/lua/mime/core.so
	$(INSTALL_DIR) $(1)/usr/lib/lua/socket
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/{ftp,http,smtp,tp,url,headers}.lua $(1)/usr/lib/lua/socket
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/unix.so $(1)/usr/lib/lua/socket
	ln -sf ../socket-3.0-rc1.so $(1)/usr/lib/lua/socket/core.so
endef

$(eval $(call BuildPackage,luasocket))
