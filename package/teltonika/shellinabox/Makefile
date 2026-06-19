#
# Copyright (C) 2006-2011 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/download.mk

PKG_NAME:=shellinabox
PKG_VERSION:=2026-04-07
PKG_RELEASE:=6
PKG_BUILD_DEPENDS:=uhttpd

PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=v2.20
PKG_SOURCE_URL:=https://github.com/shellinabox/shellinabox.git
PKG_HASH:=1255ce345628653a779033ed2a2bb464f97e1fb1d70475520d3c95c43734df65

PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_SOURCE_VERSION)-$(PKG_VERSION)

PKG_LICENSE:=GPL-2.0-only
PKG_LICENSE_FILES:=COPYING

PKG_FIXUP:=autoreconf
GPL_INCLUDE_SRC:=1

TARGET_CFLAGS += -DHAS_DEBUG

include $(INCLUDE_DIR)/uclibc++.mk
include $(INCLUDE_DIR)/package.mk

define Package/shellinabox
  SECTION:=net
  CATEGORY:=Network
  TITLE:=SSH over HTTP
  DEPENDS:= +libtlt-logger +libuci
  USERID:=shellinabox:shellinabox
endef

define Package/shellinabox/description
endef

CONFIGURE_ARGS += --disable-pam

define Build/Configure
	$(call Build/Configure/Default)
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		$(TARGET_CONFIGURE_OPTS) \
		CFLAGS="$(TARGET_CFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS) -lm" \
		DL_DIR="$(TOPDIR)/dl/$(PKG_NAME)-$(PKG_VERSION)-npx" \
		all
endef

define Build/InstallDev
endef

define Package/shellinabox/conffiles
/etc/config/cli
endef

define Package/shellinabox/install
	$(INSTALL_DIR) $(1)/etc/config $(1)/usr/lib $(1)/etc/init.d
	$(INSTALL_CONF_USR) files/cli.conf $(1)/etc/config/cli
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/.libs/uhttpd_cli.so $(1)/usr/lib/
	$(INSTALL_BIN_USR) files/shellinabox.init $(1)/etc/init.d/shellinabox

	$(INSTALL_DIR) $(1)/etc/uci-defaults/7.22
	$(INSTALL_DATA) files/migrations/99_cli_update $(1)/etc/uci-defaults/7.22/99_cli_update
endef

$(eval $(call BuildPackage,shellinabox))
