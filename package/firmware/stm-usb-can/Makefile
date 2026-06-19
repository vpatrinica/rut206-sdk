include $(TOPDIR)/rules.mk

PKG_NAME:=stm-usb-can
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

PKG_SOURCE_DATE:=2025-11-04
PKG_SOURCE_VERSION:=1.1.4

PKG_BUILD_DEPENDS:=gcc10-arm-none-eabi/host dfu-util/host

include $(INCLUDE_DIR)/package.mk

define Build/Compile
	cmake -S $(PKG_BUILD_DIR) -B $(PKG_BUILD_DIR) \
		-DTOOLCHAIN_BIN_DIR="$(STAGING_DIR_HOSTPKG)/gcc-ext/bin" \
		-DCMAKE_TOOLCHAIN_FILE=$(PKG_BUILD_DIR)/cmake/gcc-arm-none-eabi-update.cmake \
		-DSOURCE_DATE=$(PKG_SOURCE_DATE) \
		-DSOURCE_VERSION=$(PKG_SOURCE_VERSION) \
		-DPKG_SRC_PATH=$(CURDIR)
	$(call Build/Compile/Default)
endef

define Package/stm-usb-can
	SECTION:=firmware
	CATEGORY:=Firmware
	TITLE:=STM based usb can adapter for RUT204
endef

define Package/stm-usb-can/install
	$(INSTALL_DIR) $(1)/lib/firmware/ $(1)/etc/uci-defaults/etc/
	$(CP) $(PKG_BUILD_DIR)/tlt_rut204_fw.dfu $(1)/lib/firmware/tlt_rut204_fw.dfu
	$(CP) $(PKG_BUILD_DIR)/files/99_stm32_flash $(1)/etc/uci-defaults/etc/99_stm32_flash
endef

$(eval $(call BuildPackage,stm-usb-can))
