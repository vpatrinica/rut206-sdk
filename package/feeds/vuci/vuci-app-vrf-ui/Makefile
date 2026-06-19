include $(TOPDIR)/rules.mk

APP_TITLE:=VuCI UI Support for VRF

ifneq (,$(filter m,$(CONFIG_PACKAGE_vuci-app-vrf-ui))$(DUMP))
	APP_APP_NAME:=vrf
	APP_TLT_NAME:=VRF
	APP_ROUTER:=$(TLT_PLATFORM_NAME)
	PKG_NETWORK_RESTART:=1
endif

include ../app.mk

# call BuildPackage - OpenWrt buildroot signature
