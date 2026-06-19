include $(TOPDIR)/rules.mk

APP_TITLE:=VuCI UI Support for Example APP
APP_NAME:=$(notdir ${CURDIR})
CLOSED_GPL_INSTALL:=y

# APP_TLT_NAME and APP_ROUTER are needed for the package to show up in the Package manager.
# Only the main package should have these - dependencies should not, otherwise they will show up in the Package manager as well.
ifneq (,$(filter m,$(CONFIG_PACKAGE_$(APP_NAME)))$(DUMP))
	APP_TLT_NAME:=Example Application
	APP_ROUTER:=$(TLT_PLATFORM_NAME)
endif

define Package/$(APP_NAME)/description
	Example UI application
endef

include ../app.mk

# call BuildPackage - OpenWrt buildroot signature
