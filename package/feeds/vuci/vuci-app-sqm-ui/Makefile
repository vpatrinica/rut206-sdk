include $(TOPDIR)/rules.mk

APP_TITLE:=VuCI UI Support for SQM

ifneq (,$(filter m,$(CONFIG_PACKAGE_vuci-app-sqm-ui))$(DUMP))
	APP_APP_NAME:=sqm-scripts
	APP_TLT_NAME:=SQM
	APP_ROUTER:=$(TLT_PLATFORM_NAME)
endif

include ../app.mk

# call BuildPackage - OpenWrt buildroot signature
