#
# Copyright (C) 2006-2014 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=emailrelay
PKG_VERSION:=2025-12-22
PKG_RELEASE:=$(AUTORELEASE)-2

PKG_SOURCE_VERSION:=2.5.2
PKG_HASH:=2c879069b54156ad59bec632ae43b37645095043dbb4874712b250f23fd768ab

PKG_MAINTAINER:=Federico Di Marco <fededim@gmail.com>
PKG_LICENSE:=GPL-3.0-only
PKG_LICENSE_FILES:=COPYING
PKG_SOURCE=emailrelay-$(PKG_SOURCE_VERSION)-src.tar.gz
PKG_SOURCE_URL:=@SF/emailrelay/$(PKG_SOURCE_VERSION)

PKG_FIXUP:=autoreconf

PKG_CONFIG_DEPENDS:=CONFIG_EMAILRELAY_SUPPORT_VERBOSE_DBG CONFIG_EMAILRELAY_SSL CONFIG_EMAILRELAY_DYNAMIC_LOGGING

PKG_BUILD_FLAGS:=gc-sections lto

include $(INCLUDE_DIR)/package.mk

define Package/emailrelay
	SECTION:=mail
	CATEGORY:=Mail
	DEPENDS:=+EMAILRELAY_SSL:libopenssl +libstdcpp +EMAILRELAY_DYNAMIC_LOGGING:libtlt-logger
	TITLE:=A simple SMTP proxy and MTA
	URL:=http://emailrelay.sourceforge.net/
	USERID:=emailrelay:emailrelay
  	FATTRS:=/usr/bin/emailrelay::::cap_net_bind_service=ep
	MENU:=1
endef


define Package/emailrelay/config
config EMAILRELAY_SUPPORT_VERBOSE_DBG
	bool "Enable support for extended logging"
	depends on PACKAGE_emailrelay
	default n
	help
	  Enables support for extended logging (must also be explicitely enabled by using command line switch --debug when starting emailrelay)

config EMAILRELAY_SSL
	bool "Enable support for OpenSSL"
	depends on PACKAGE_emailrelay
	default y
	select PACKAGE_libopenssl
	help
 	  Builds the package with OpenSSL support (SSMTP is supported).

config EMAILRELAY_DYNAMIC_LOGGING
	bool "Enable support for dynamic logging level changes"
	depends on PACKAGE_emailrelay
	default y
	select PACKAGE_libtlt-logger
	help
 	  Builds the package with dynamic logging level changes support (logging level can be changed at runtime).
endef


define Package/emailrelay/description
 Emailrelay is a simple SMTP proxy and store-and-forward message transfer agent (MTA).

 When running as a proxy all e-mail messages can be passed through
 a user-defined program, such as a spam filter, which can drop,
 re-address or edit messages as they pass through. When running
 as a store-and-forward MTA incoming messages are stored in a
 local spool directory, and then forwarded to the next SMTP
 server on request.
endef


define Package/emailrelay/conffiles
/etc/config/emailrelay
endef


CONFIGURE_ARGS += \
	--without-doxygen \
	--without-man2html \
	--without-mbedtls \
	--without-pam \
	--disable-bsd \
	--disable-gui \
	--disable-mac \
	--disable-testing \
	--disable-windows

ifeq ($(CONFIG_EMAILRELAY_SSL),y)
	CONFIGURE_ARGS += \
		--with-openssl
else
	CONFIGURE_ARGS += \
		--without-openssl
endif

ifeq ($(CONFIG_EMAILRELAY_SUPPORT_VERBOSE_DBG),y)
	CONFIGURE_ARGS += \
		--enable-debug=yes
endif

ifeq ($(CONFIG_EMAILRELAY_DYNAMIC_LOGGING),y)
	CONFIGURE_ARGS += \
		--with-dynlog=yes
	CONFIGURE_VARS += \
		ac_cv_search_logger_init=-ltlt_logger
endif

TARGET_CXXFLAGS += -O1
TARGET_CXXFLAGS += -Wl,--gc-sections,--as-needed

define Package/emailrelay/install
	$(INSTALL_DIR) $(1)/usr/bin $(1)/etc/permtab.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/main/emailrelay $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/main/emailrelay-passwd $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/main/emailrelay-submit $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) files/$(PKG_NAME).config $(1)/etc/config/$(PKG_NAME)
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN_USR) files/$(PKG_NAME).init $(1)/etc/init.d/$(PKG_NAME)
	$(INSTALL_DATA) files/$(PKG_NAME).permtab $(1)/etc/permtab.d/$(PKG_NAME)
	$(INSTALL_DIR) $(1)/etc/uci-defaults/7.16/ $(1)/etc/uci-defaults/7.18/
	$(INSTALL_DATA) files/defaults/99_add_emailrelay_name $(1)/etc/uci-defaults/7.16/99_add_emailrelay_name
	$(INSTALL_DATA) files/defaults/99_add_emailrelay_name $(1)/etc/uci-defaults/7.18/99_add_emailrelay_name
endef

$(eval $(call BuildPackage,emailrelay))
