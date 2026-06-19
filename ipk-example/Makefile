#
# Copyright (C) 2025 Teltonika
#

include $(TOPDIR)/rules.mk

PKG_NAME:=example_package
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

# PKG_TLT_NAME and PKG_ROUTER are needed for the package to show up in the Package manager.
# Only the main package should have these - dependencies should not, otherwise they will show up in the Package manager as well.
define Package/example_package
	SECTION:=base
	CATEGORY:=Base system
	TITLE:=Example package
	DEPENDS:=+busybox
	ifneq (,$(filter m,$(CONFIG_PACKAGE_example_package))$(DUMP))
		PKG_TLT_NAME:=example_package
		PKG_ROUTER:=$(TLT_PLATFORM_NAME)
	endif
endef

define Build/Compile
endef

define Package/example_package/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/example.sh $(1)/usr/bin/example.sh
endef

$(eval $(call BuildPackage,example_package))
