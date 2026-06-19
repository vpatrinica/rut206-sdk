include $(TOPDIR)/rules.mk

APP_TITLE:=VuCI API Support for I/O Juggler
APP_DEPENDS:=+event-juggler

ifeq (m, $(CONFIG_PACKAGE_vuci-app-io-juggler-api))
	APP_TLT_NAME:=I/O Juggler API
	APP_APP_NAME:=io_juggler
	APP_ROUTER:=$(TLT_PLATFORM_NAME)
	APP_HW_INFO:=ios
endif

include ../api.mk

# call BuildPackage - OpenWrt buildroot signature
