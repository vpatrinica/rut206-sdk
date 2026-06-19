include $(TOPDIR)/rules.mk

APP_TITLE:=VuCI API Support for Events Reporting
APP_DEPENDS:=+event-juggler +libparam +libubus +luajit2 +MOBILE_SUPPORT:libgsm

ifeq (m, $(CONFIG_PACKAGE_vuci-app-events-reporting-api))
	APP_TLT_NAME:=Events reporting API
	APP_APP_NAME:=events_reporting
	APP_ROUTER:=$(TLT_PLATFORM_NAME)
endif

CUSTOM_INSTALL=1
include ../api.mk

ifneq ($(CONFIG_GPL_INCLUDE_WEB_SOURCES), y)
endif

TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include/luajit-2.1

define Package/$(PKG_NAME)/install
	$(call Package/$(PKG_NAME)/install/Default,$(1))
	$(INSTALL_DIR) $(1)/usr/lib/lua/
	$(CP) $(PKG_BUILD_DIR)/lualibparam.so $(1)/usr/lib/lua/
endef

# call BuildPackage - OpenWrt buildroot signature
$(eval $(call BuildPackage,$(PKG_NAME)))
