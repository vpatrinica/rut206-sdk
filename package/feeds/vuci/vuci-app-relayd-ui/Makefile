include $(TOPDIR)/rules.mk

APP_TITLE:=VuCI UI Support for relayd

ifneq (,$(filter m,$(CONFIG_PACKAGE_vuci-app-relayd-ui))$(DUMP))
	APP_APP_NAME:=relay_configuration
	APP_TLT_NAME:=Relay configuration
	APP_ROUTER:=$(TLT_PLATFORM_NAME)
endif

include ../app.mk

# call BuildPackage - OpenWrt buildroot signature
