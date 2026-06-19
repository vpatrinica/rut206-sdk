include $(TOPDIR)/rules.mk

APP_TITLE:=VuCI UI Support for SMCRoutes (Multicast Routes)

ifeq (m, $(CONFIG_PACKAGE_vuci-app-smcroute-ui))
	APP_APP_NAME:=smcroute
	APP_TLT_NAME:=SMCRoutes
	APP_ROUTER:=$(TLT_PLATFORM_NAME)
endif

include ../app.mk

define Package/vuci-app-smcroute-ui/description
	SMCRoute is a command line tool to manipulate the multicast routes of the Linux kernel.
endef

# call BuildPackage - OpenWrt buildroot signature
