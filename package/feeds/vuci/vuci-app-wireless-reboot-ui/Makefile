include $(TOPDIR)/rules.mk

APP_TITLE:=VuCI UI Support for Wireless Reboot

ifneq (,$(filter m,$(CONFIG_PACKAGE_vuci-app-wireless-reboot-ui))$(DUMP))
	APP_TLT_NAME:=Wireless Reboot
	APP_APP_NAME:=wireless_reboot
	APP_ROUTER:=$(TLT_PLATFORM_NAME)
	APP_HW_INFO:=wifi
endif

include ../app.mk

define Package/vuci-app-wireless-reboot-ui/description
	Wireless Reboot application allows users to schedule automatic
	reboots of device's wireless system, based on wireless hang statistics.
endef

# call BuildPackage - OpenWrt buildroot signature
