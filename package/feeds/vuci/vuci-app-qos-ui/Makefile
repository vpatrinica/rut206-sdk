include $(TOPDIR)/rules.mk

APP_TITLE:=VuCI UI Support for QoS

ifneq (,$(filter m,$(CONFIG_PACKAGE_vuci-app-qos-ui))$(DUMP))
	APP_APP_NAME:=qos-scripts
	APP_TLT_NAME:=QoS
	APP_ROUTER:=$(TLT_PLATFORM_NAME)
endif

include ../app.mk

# call BuildPackage - OpenWrt buildroot signature
