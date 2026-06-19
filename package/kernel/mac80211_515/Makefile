#
# Copyright (C) 2007-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=mac80211_515

PKG_VERSION:=6.5
PKG_RELEASE:=2

PKG_SOURCE_VERSION:=6.5
PKG_SOURCE:=backports-$(PKG_SOURCE_VERSION).tar.xz
PKG_SOURCE_URL:=http://mirror2.openwrt.org/sources/

PKG_HASH:=908c22dceba185eab83caa5a1e58ce6b3ebdc58f099c3fd3e11c7352ebfab2d7
PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/backports-$(PKG_VERSION)
PKG_BUILD_PARALLEL:=1

PKG_LICENSE:=GPL-2.0-only
PKG_LICENSE_FILES:=COPYING
PKG_MAINTAINER:=Felix Fietkau <nbd@nbd.name>

PKG_DRIVERS = \
	adm8211_515 \
	airo_515 \
	hermes_515 hermes-pci_515 hermes-pcmcia_515 hermes-plx_515 \
	lib80211_515 \
	mac80211-hwsim_515 \
	mt7601u_515 \
	p54-common_515 p54-pci_515 p54-usb_515 \
	rsi91x_515 rsi91x-usb_515 rsi91x-sdio_515 \
	wlcore_515 wl12xx_515 wl18xx_515 \
	zd1211rw_515

PKG_CONFIG_DEPENDS:= \
	CONFIG_PACKAGE_kmod-mac80211_515 \
	CONFIG_PACKAGE_CFG80211_TESTMODE \
	CONFIG_PACKAGE_MAC80211_DEBUGFS \
	CONFIG_PACKAGE_MAC80211_MESH \
	CONFIG_PACKAGE_MAC80211_TRACING \
	CONFIG_PACKAGE_IWLWIFI_DEBUG \
	CONFIG_PACKAGE_IWLWIFI_DEBUGFS \
	CONFIG_PACKAGE_RTLWIFI_DEBUG \

include $(INCLUDE_DIR)/package.mk

WMENU:=Wireless Drivers

define KernelPackage/mac80211_515/Default
  SUBMENU:=$(WMENU)
  URL:=https://wireless.wiki.kernel.org/
  MAINTAINER:=Felix Fietkau <nbd@nbd.name>
endef

config_package=$(if $(CONFIG_PACKAGE_kmod-$(1)),m)

config-y:= \
	WLAN \
	CFG80211_WEXT \
	CFG80211_CERTIFICATION_ONUS \
	MAC80211_RC_MINSTREL \
	MAC80211_RC_MINSTREL_HT \
	MAC80211_RC_MINSTREL_VHT \
	MAC80211_RC_DEFAULT_MINSTREL \
	WLAN_VENDOR_ADMTEK \
	WLAN_VENDOR_ATH \
	WLAN_VENDOR_ATMEL \
	WLAN_VENDOR_BROADCOM \
	WLAN_VENDOR_CISCO \
	WLAN_VENDOR_INTEL \
	WLAN_VENDOR_INTERSIL \
	WLAN_VENDOR_MARVELL \
	WLAN_VENDOR_MEDIATEK \
	WLAN_VENDOR_RALINK \
	WLAN_VENDOR_REALTEK \
	WLAN_VENDOR_RSI \
	WLAN_VENDOR_ST \
	WLAN_VENDOR_TI \
	WLAN_VENDOR_ZYDAS \

config-$(call config_package,cfg80211_515) += CFG80211
config-$(CONFIG_PACKAGE_CFG80211_TESTMODE) += NL80211_TESTMODE

config-$(call config_package,mac80211_515) += MAC80211
config-$(CONFIG_PACKAGE_MAC80211_MESH) += MAC80211_MESH

include ath.mk
include broadcom.mk
include intel.mk
include marvell.mk
include ralink.mk
include realtek.mk

PKG_CONFIG_DEPENDS += \
	$(patsubst %,CONFIG_PACKAGE_kmod-%,$(PKG_DRIVERS))

define KernelPackage/cfg80211_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=cfg80211 - wireless configuration API
  DEPENDS+= +iw-515 +iwinfo +wifi-scripts +wireless-regdb +USE_RFKILL:kmod-rfkill
  ABI_VERSION:=$(PKG_VERSION)-$(PKG_RELEASE)
  FILES:= \
	$(PKG_BUILD_DIR)/compat/compat.ko \
	$(PKG_BUILD_DIR)/net/wireless/cfg80211.ko
  ifneq ($(CONFIG_USES_VENDOR_WIFI_DRIVER),)
	AUTOLOAD:=$(call AutoProbe,cfg80211)
  endif
endef

define KernelPackage/cfg80211_515/description
cfg80211 is the Linux wireless LAN (802.11) configuration API.
endef

define KernelPackage/cfg80211_515/config
  if PACKAGE_kmod-cfg80211_515

	config PACKAGE_CFG80211_TESTMODE
		bool "Enable testmode command support"
		default n
		help
		  This is typically used for tests and calibration during
		  manufacturing, or vendor specific debugging features

  endif
endef


define KernelPackage/mac80211_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=Linux 802.11 Wireless Networking Stack
  # +kmod-crypto-cmac is a runtime only dependency of net/mac80211/aes_cmac.c
  DEPENDS+= +kmod-cfg80211_515 +kmod-crypto-cmac +kmod-crypto-ccm +kmod-crypto-gcm +hostapd-common
  KCONFIG:=\
	CONFIG_AVERAGE=y
  FILES:= $(PKG_BUILD_DIR)/net/mac80211/mac80211.ko
  ABI_VERSION:=$(PKG_VERSION)-$(PKG_RELEASE)
  MENU:=1
endef

define KernelPackage/mac80211_515/config
  if PACKAGE_kmod-mac80211_515

	config PACKAGE_MAC80211_DEBUGFS
		bool "Export mac80211 internals in DebugFS"
		select KERNEL_DEBUG_FS
		default y
		help
		  Select this to see extensive information about
		  the internal state of mac80211 in debugfs.

	config PACKAGE_MAC80211_TRACING
		bool "Enable tracing (mac80211 and supported drivers)"
		select KERNEL_FTRACE
		select KERNEL_ENABLE_DEFAULT_TRACERS
		default n
		help
		  Select this to enable tracing of mac80211 and
		  related wifi drivers (using trace-cmd).

	config PACKAGE_MAC80211_MESH
		bool "Enable 802.11s mesh support"
		default y

  endif
endef

define KernelPackage/mac80211_515/description
Generic IEEE 802.11 Networking Stack (mac80211)
endef

define KernelPackage/adm8211_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=ADMTek 8211 support
  DEPENDS+=@PCI_SUPPORT +kmod-mac80211_515 +kmod-eeprom-93cx6
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/admtek/adm8211.ko
  AUTOLOAD:=$(call AutoProbe,adm8211)
endef

define KernelPackage/airo_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=Cisco Aironet driver
  DEPENDS+=@PCI_SUPPORT +@DRIVER_WEXT_SUPPORT +kmod-cfg80211_515 @TARGET_x86 @BROKEN
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/cisco/airo.ko
  AUTOLOAD:=$(call AutoProbe,airo)
endef

define KernelPackage/airo_515/description
 Kernel support for Cisco Aironet cards
endef

define KernelPackage/hermes_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=Hermes 802.11b chipset support
  DEPENDS:=@PCI_SUPPORT||PCMCIA_SUPPORT +kmod-cfg80211_515 +@DRIVER_WEXT_SUPPORT +kmod-crypto-michael-mic
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/intersil/orinoco/orinoco.ko
  AUTOLOAD:=$(call AutoProbe,orinoco)
endef

define KernelPackage/hermes_515/description
 Kernel support for Hermes 802.11b chipsets
endef

define KernelPackage/hermes-pci_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=Intersil Prism 2.5 PCI support
  DEPENDS:=@PCI_SUPPORT +kmod-hermes_515
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/intersil/orinoco/orinoco_pci.ko
  AUTOLOAD:=$(call AutoProbe,orinoco_pci)
endef

define KernelPackage/hermes-pci_515/description
 Kernel modules for Intersil Prism 2.5 PCI support
endef

define KernelPackage/hermes-plx_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=PLX9052 based PCI adaptor
  DEPENDS:=@PCI_SUPPORT +kmod-hermes_515
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/intersil/orinoco/orinoco_plx.ko
  AUTOLOAD:=$(call AutoProbe,orinoco_plx)
endef

define KernelPackage/hermes-plx_515/description
 Kernel modules for Hermes in PLX9052 based PCI adaptors
endef

define KernelPackage/hermes-pcmcia_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=Hermes based PCMCIA adaptors
  DEPENDS:=@PCMCIA_SUPPORT +kmod-hermes_515 +kmod-pcmcia-core
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/intersil/orinoco/orinoco_cs.ko
  AUTOLOAD:=$(call AutoProbe,orinoco_cs)
endef

define KernelPackage/hermes-pcmcia_515/description
 Kernel modules for Hermes based PCMCIA adaptors
endef


define KernelPackage/lib80211_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=802.11 Networking stack
  DEPENDS:=+kmod-cfg80211_515 +kmod-crypto-hash +kmod-crypto-ccm
  FILES:= \
	$(PKG_BUILD_DIR)/net/wireless/lib80211.ko \
	$(PKG_BUILD_DIR)/net/wireless/lib80211_crypt_wep.ko \
	$(PKG_BUILD_DIR)/net/wireless/lib80211_crypt_ccmp.ko \
	$(PKG_BUILD_DIR)/net/wireless/lib80211_crypt_tkip.ko
  AUTOLOAD:=$(call AutoProbe, \
	lib80211 \
	lib80211_crypt_wep \
	lib80211_crypt_ccmp \
	lib80211_crypt_tkip \
  )
endef

define KernelPackage/lib80211_515/description
 Kernel modules for 802.11 Networking stack
 Includes:
 - lib80211
 - lib80211_crypt_wep
 - lib80211_crypt_tkip
 - lib80211_crytp_ccmp
endef


define KernelPackage/mac80211-hwsim_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=mac80211 HW simulation device
  DEPENDS+= +kmod-mac80211_515 +@DRIVER_11AX_SUPPORT +@DRIVER_11AC_SUPPORT +@DRIVER_11N_SUPPORT
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/virtual/mac80211_hwsim.ko
  AUTOLOAD:=$(call AutoProbe,mac80211_hwsim)
endef


define KernelPackage/mt7601u_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=MT7601U-based USB dongles Wireless Driver
  DEPENDS+= +kmod-mac80211_515 +@DRIVER_11N_SUPPORT @USB_SUPPORT +kmod-usb-core +mt7601u-firmware
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/mediatek/mt7601u/mt7601u.ko
  AUTOLOAD:=$(call AutoProbe,mt7601u)
endef

define KernelPackage/p54_515/Default
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=Prism54 Drivers
endef

define KernelPackage/p54_515/description
  Kernel module for Prism54 chipsets (mac80211)
endef

define KernelPackage/p54-common_515
  $(call KernelPackage/p54/Default)
  DEPENDS+= @(PCI_SUPPORT||USB_SUPPORT) +kmod-mac80211_515 +kmod-lib-crc-ccitt
  TITLE+= (COMMON)
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/intersil/p54/p54common.ko
endef

define KernelPackage/p54-pci_515
  $(call KernelPackage/p54_515/Default)
  TITLE+= (PCI)
  DEPENDS+= @PCI_SUPPORT +kmod-p54-common_515
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/intersil/p54/p54pci.ko
  AUTOLOAD:=$(call AutoProbe,p54pci)
endef

define KernelPackage/p54-usb_515
  $(call KernelPackage/p54_515/Default)
  TITLE+= (USB)
  DEPENDS+= @USB_SUPPORT +kmod-usb-core +kmod-p54-common_515
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/intersil/p54/p54usb.ko
  AUTOLOAD:=$(call AutoProbe,p54usb)
endef

define KernelPackage/rsi91x_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=Redpine Signals Inc 91x WLAN driver support
  DEPENDS+= +kmod-mac80211_515 +rs9113-firmware +@DRIVER_11N_SUPPORT
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/rsi/rsi_91x.ko
endef

define KernelPackage/rsi91x-usb_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=Redpine Signals USB bus support
  DEPENDS+=@USB_SUPPORT +kmod-usb-core +kmod-mac80211_515 +kmod-rsi91x_515 +rs9113-firmware
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/rsi/rsi_usb.ko
  AUTOLOAD:=$(call AutoProbe,rsi_usb)
endef

define KernelPackage/rsi91x-sdio_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=Redpine Signals SDIO bus support
  DEPENDS+= +kmod-mac80211_515 +kmod-mmc +kmod-rsi91x_515 +rs9113-firmware
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/rsi/rsi_sdio.ko
  AUTOLOAD:=$(call AutoProbe,rsi_sdio)
endef


define KernelPackage/wlcore_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=TI common driver part
  DEPENDS+= +kmod-mmc +kmod-mac80211_515 +@DRIVER_11N_SUPPORT
  FILES:= \
	$(PKG_BUILD_DIR)/drivers/net/wireless/ti/wlcore/wlcore.ko \
	$(PKG_BUILD_DIR)/drivers/net/wireless/ti/wlcore/wlcore_sdio.ko
  AUTOLOAD:=$(call AutoProbe,wlcore wlcore_sdio)
endef

define KernelPackage/wlcore_515/description
 This module contains some common parts needed by TI Wireless drivers.
endef

define KernelPackage/wl12xx_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=Driver for TI WL12xx
  URL:=https://wireless.wiki.kernel.org/en/users/drivers/wl12xx
  DEPENDS+= +kmod-wlcore_515 +wl12xx-firmware
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/ti/wl12xx/wl12xx.ko
  AUTOLOAD:=$(call AutoProbe,wl12xx)
endef

define KernelPackage/wl12xx_515/description
 Kernel modules for TI WL12xx
endef

define KernelPackage/wl18xx_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=Driver for TI WL18xx_515
  URL:=https://wireless.wiki.kernel.org/en/users/drivers/wl18xx
  DEPENDS+= +kmod-wlcore_515 +wl18xx-firmware
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/ti/wl18xx/wl18xx.ko
  AUTOLOAD:=$(call AutoProbe,wl18xx)
endef

define KernelPackage/wl18xx_515/description
 Kernel modules for TI WL18xx_515
endef


ZD1211FW_NAME:=zd1211-firmware
ZD1211FW_VERSION:=1.4
define Download/zd1211rw_515
  FILE:=$(ZD1211FW_NAME)-$(ZD1211FW_VERSION).tar.bz2
  URL:=@SF/zd1211/
  HASH:=866308f6f59f7075f075d4959dff2ede47735c751251fecd1496df1ba4d338e1
endef
$(eval $(call Download,zd1211rw_515))

define KernelPackage/zd1211rw_515
  $(call KernelPackage/mac80211_515/Default)
  TITLE:=Zydas ZD1211 support
  DEPENDS+= @USB_SUPPORT +kmod-usb-core +kmod-mac80211_515
  FILES:=$(PKG_BUILD_DIR)/drivers/net/wireless/zydas/zd1211rw/zd1211rw.ko
  AUTOLOAD:=$(call AutoProbe,zd1211rw)
endef

ifdef CONFIG_PACKAGE_MAC80211_DEBUGFS
  config-y += \
	CFG80211_DEBUGFS \
	MAC80211_DEBUGFS
endif

ifdef CONFIG_PACKAGE_MAC80211_TRACING
  config-y += \
	IWLWIFI_DEVICE_TRACING
endif

config-$(call config_package,lib80211_515) += LIB80211 LIB80211_CRYPT_WEP LIB80211_CRYPT_CCMP LIB80211_CRYPT_TKIP

config-$(call config_package,airo_515) += AIRO

config-$(call config_package,mac80211-hwsim_515) += MAC80211_HWSIM
config-$(call config_package,mt7601u_515) += MT7601U
config-y += WL_MEDIATEK

config-$(call config_package,p54-common_515) += P54_COMMON
config-$(call config_package,p54-pci_515) += P54_PCI
config-$(call config_package,p54-usb_515) += P54_USB

config-$(call config_package,hermes_515) += HERMES
config-$(call config_package,hermes-pci_515) += PCI_HERMES
config-$(call config_package,hermes-plx_515) += PLX_HERMES
config-$(call config_package,hermes-pcmcia_515) += PCMCIA_HERMES
config-y += HERMES_PRISM

config-$(call config_package,adm8211_515) += ADM8211
config-$(call config_package,wlcore_515) += WLCORE WLCORE_SDIO
config-$(call config_package,wl12xx_515) += WL12XX
config-$(call config_package,wl18xx_515) += WL18XX
config-y += WL_TI WILINK_PLATFORM_DATA
config-$(call config_package,zd1211rw_515) += ZD1211RW
config-$(call config_package,rsi91x_515) += RSI_91X
config-$(call config_package,rsi91x-usb_515) += RSI_USB
config-$(call config_package,rsi91x-sdio_515) += RSI_SDIO

config-$(CONFIG_LEDS_TRIGGERS) += MAC80211_LEDS

C_DEFINES=

ifeq ($(BUILD_VARIANT),smallbuffers)
	C_DEFINES+= -DCONFIG_ATH10K_SMALLBUFFERS
endif

MAKE_OPTS:= -C "$(PKG_BUILD_DIR)" \
	$(KERNEL_MAKE_FLAGS) \
	EXTRA_CFLAGS="-I$(PKG_BUILD_DIR)/include $(IREMAP_CFLAGS) $(C_DEFINES)" \
	KLIB_BUILD="$(LINUX_DIR)" \
	MODPROBE=true \
	KLIB=$(TARGET_MODULES_DIR) \
	KERNEL_SUBLEVEL=$(lastword $(subst ., ,$(KERNEL_PATCHVER))) \
	KBUILD_LDFLAGS_MODULE_PREREQ=

define ConfigVars
$(subst $(space),,$(foreach opt,$(config-$(1)),CPTCFG_$(opt)=$(1)
))
endef

define mac80211_config_515
$(call ConfigVars,m)$(call ConfigVars,y)
endef
$(eval $(call shexport,mac80211_config_515))

define Build/Prepare
	rm -rf $(PKG_BUILD_DIR)
	mkdir -p $(PKG_BUILD_DIR)
	$(PKG_UNPACK)
	$(Build/Patch)
	$(TAR) -C $(PKG_BUILD_DIR) -xzf $(DL_DIR)/$(IPW2100_NAME)-$(IPW2100_VERSION).tgz
	$(TAR) -C $(PKG_BUILD_DIR) -xzf $(DL_DIR)/$(IPW2200_NAME)-$(IPW2200_VERSION).tgz
	$(TAR) -C $(PKG_BUILD_DIR) -xjf $(DL_DIR)/$(ZD1211FW_NAME)-$(ZD1211FW_VERSION).tar.bz2
	rm -rf \
		$(PKG_BUILD_DIR)/include/linux/ssb \
		$(PKG_BUILD_DIR)/include/linux/bcma \
		$(PKG_BUILD_DIR)/include/net/bluetooth

	rm -f \
		$(PKG_BUILD_DIR)/include/linux/cordic.h \
		$(PKG_BUILD_DIR)/include/linux/crc8.h \
		$(PKG_BUILD_DIR)/include/linux/eeprom_93cx6.h \
		$(PKG_BUILD_DIR)/include/linux/wl12xx.h \
		$(PKG_BUILD_DIR)/include/linux/mhi.h \
		$(PKG_BUILD_DIR)/include/linux/spi/libertas_spi.h \
		$(PKG_BUILD_DIR)/include/net/ieee80211.h \
		$(PKG_BUILD_DIR)/backport-include/linux/bcm47xx_nvram.h

	echo 'compat-wireless-$(PKG_VERSION)-$(PKG_RELEASE)-$(REVISION)' > $(PKG_BUILD_DIR)/compat_version
endef

ifneq ($(CONFIG_PACKAGE_kmod-cfg80211_515)$(CONFIG_PACKAGE_kmod-lib80211_515),)
 define Build/Compile/kmod
	rm -rf $(PKG_BUILD_DIR)/modules
	+$(MAKE) $(PKG_JOBS) $(MAKE_OPTS) modules
 endef
endif

#do not Build/Configure for EXTERNAL KERNEL
ifeq ($(strip $(CONFIG_EXTERNAL_KERNEL_TREE)),"")
  ifeq ($(strip $(CONFIG_KERNEL_GIT_CLONE_URI)),"")
    define Build/Configure
	  cmp $(PKG_BUILD_DIR)/include/linux/ath9k_platform.h $(LINUX_DIR)/include/linux/ath9k_platform.h
	  cmp $(PKG_BUILD_DIR)/include/linux/ath5k_platform.h $(LINUX_DIR)/include/linux/ath5k_platform.h
	  cmp $(PKG_BUILD_DIR)/include/linux/rt2x00_platform.h $(LINUX_DIR)/include/linux/rt2x00_platform.h
    endef
  endif
endif

define Build/Patch
	$(if $(QUILT),rm -rf $(PKG_BUILD_DIR)/patches; mkdir -p $(PKG_BUILD_DIR)/patches)
	$(call PatchDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/build,build/)
	$(call PatchDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/subsys,subsys/)
	$(call PatchDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/ath,ath/)
	$(call PatchDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/ath5k,ath5k/)
	$(call PatchDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/ath9k,ath9k/)
	$(call PatchDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/ath10k,ath10k/)
	$(call PatchDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/ath11k,ath11k/)
	$(call PatchDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/rt2x00,rt2x00/)
	$(call PatchDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/mt7601u,mt7601u/)
	$(call PatchDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/mwl,mwl/)
	$(call PatchDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/brcm,brcm/)
	$(call PatchDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/rtl,rtl/)
	$(if $(QUILT),touch $(PKG_BUILD_DIR)/.quilt_used)
endef

define Quilt/Refresh/Package
	$(call Quilt/RefreshDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/build,build/)
	$(call Quilt/RefreshDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/subsys,subsys/)
	$(call Quilt/RefreshDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/ath,ath/)
	$(call Quilt/RefreshDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/ath5k,ath5k/)
	$(call Quilt/RefreshDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/ath9k,ath9k/)
	$(call Quilt/RefreshDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/ath10k,ath10k/)
	$(call Quilt/RefreshDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/ath11k,ath11k/)
	$(call Quilt/RefreshDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/rt2x00,rt2x00/)
	$(call Quilt/RefreshDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/mt7601u,mt7601u/)
	$(call Quilt/RefreshDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/mwl,mwl/)
	$(call Quilt/RefreshDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/brcm,brcm/)
	$(call Quilt/RefreshDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/rtl,rtl/)
endef

define Build/Compile
	$(SH_FUNC) var2file "$(call shvar,mac80211_config_515)" $(PKG_BUILD_DIR)/.config
	$(MAKE) $(MAKE_OPTS) allnoconfig
	$(call Build/Compile/kmod)
endef

define Build/InstallDev
	mkdir -p \
		$(1)/usr/include/mac80211 \
		$(1)/usr/include/mac80211-backport \
		$(1)/usr/include/mac80211/ath \
		$(1)/usr/include/net/mac80211
	$(CP) $(PKG_BUILD_DIR)/net/mac80211/*.h $(PKG_BUILD_DIR)/include/* $(1)/usr/include/mac80211/
	$(CP) $(PKG_BUILD_DIR)/backport-include/* $(1)/usr/include/mac80211-backport/
	$(CP) $(PKG_BUILD_DIR)/net/mac80211/rate.h $(1)/usr/include/net/mac80211/
	$(CP) $(PKG_BUILD_DIR)/drivers/net/wireless/ath/*.h $(1)/usr/include/mac80211/ath/
	rm -f $(1)/usr/include/mac80211-backport/linux/module.h
endef

define KernelPackage/zd1211rw_515/install
	$(INSTALL_DIR) $(1)/lib/firmware/zd1211
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/$(ZD1211FW_NAME)/zd1211* $(1)/lib/firmware/zd1211
endef

$(eval $(foreach drv,$(PKG_DRIVERS),$(call KernelPackage,$(drv))))
$(eval $(call KernelPackage,cfg80211_515))
$(eval $(call KernelPackage,mac80211_515))
