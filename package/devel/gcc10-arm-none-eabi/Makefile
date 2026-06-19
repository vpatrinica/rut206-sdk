#
# Copyright (C) 2024 Teltonika-Networks
#

include $(TOPDIR)/rules.mk

PKG_NAME:=gcc10-arm-none-eabi
PKG_VERSION:=10.3

PKG_SOURCE:=gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2
PKG_SOURCE_URL:=https://developer.arm.com/-/media/Files/downloads/gnu-rm/10.3-2021.10
PKG_HASH:=97dbb4f019ad1650b732faffcc881689cedc14e2b7ee863d390e0a41ef16c9a3

PKG_LICENSE:=GPL-3.0-with-GCC-exception

include $(INCLUDE_DIR)/host-build.mk
include $(INCLUDE_DIR)/package.mk

define Host/Prepare
	rm -rf $(PKG_BUILD_DIR)
	mkdir -p $(PKG_BUILD_DIR)
	$(TAR) -xf $(DL_DIR)/$(PKG_SOURCE) -C $(HOST_BUILD_DIR) --strip 1
endef

define Host/Configure
endef

define Host/Compile
endef

GCC_INSTALL_DIR:=$(STAGING_DIR_HOSTPKG)/gcc-ext

define Host/Install
	rm -rf $(GCC_INSTALL_DIR)
	mkdir -p $(GCC_INSTALL_DIR)
	mv $(HOST_BUILD_DIR)/* $(GCC_INSTALL_DIR)
endef

define Host/Clean
	$(call Host/Clean/Default)
	rm -f $(GCC_INSTALL_DIR)
endef

define Package/gcc10-arm-none-eabi
  SECTION:=devel
  CATEGORY:=Development
  TITLE:=gcc10-arm-none-eabi
  URL:=https://developer.arm.com/
endef

$(eval $(call HostBuild))
$(eval $(call BuildPackage,gcc10-arm-none-eabi))