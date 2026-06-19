include $(TOPDIR)/rules.mk

APP_TITLE:=VuCI UI Support for Networkmap

ifneq (,$(filter m,$(CONFIG_PACKAGE_vuci-app-networkmap-ui))$(DUMP))
	APP_TLT_NAME:=Topology
	APP_ROUTER:=$(TLT_PLATFORM_NAME)
	APP_APP_NAME:=topology
endif

include ../app.mk

define Package/vuci-app-networkmap-ui/description
	Displays network devices that belong to the same network.
endef

# call BuildPackage - OpenWrt buildroot signature
