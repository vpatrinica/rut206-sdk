#
# MT76x8 Profiles
#
include common-teltonika.mk
include devices/common_mt76x8.mk
include devices/otd1xx_family.mk
include devices/tap1xx_family.mk
include devices/trb2xx_family.mk
include devices/rut1xx_family.mk
include devices/dap1xx_family.mk
include devices/rut2xx_family.mk
include devices/rut3xx_family.mk
include devices/rut9xx_family.mk

KERNEL_LOADADDR := 0x80000000

define Device/tlt-mt7628-common
	SOC := mt7628an

	DEVICE_FEATURES := small_flash sw-offload dot1x-client 128mb_ram reset_button

	MTDPARTS :=
	BLOCKSIZE := 64k
	KERNEL := kernel-bin | append-dtb | lzma | uImage lzma
	KERNEL_INITRAMFS := kernel-bin | append-dtb | lzma | uImage lzma
	DEVICE_DTS = $$(SOC)_$(1)
	DEVICE_MTD_LOG_PARTNAME := mtdblock7

	UBOOT_SIZE := 131072
	CONFIG_SIZE := 65536
	ART_SIZE := 196608
	NO_ART := 0
	IMAGE_SIZE := 15424k
	MASTER_IMAGE_SIZE := 16384k
	CONFIG_END = $$(shell expr $$(UBOOT_SIZE) + $$(CONFIG_SIZE))
	ART_END = $$(shell expr $$(CONFIG_END) + $$(ART_SIZE))
	HW_MODS := blv1


	IMAGE/sysupgrade.bin = \
			append-kernel | pad-to $$$$(BLOCKSIZE) | \
			append-rootfs | check-size 999m | \
			pad-rootfs | check-size $$$$(IMAGE_SIZE) | \
			append-metadata | finalize-tlt-webui

	IMAGE/master_fw.bin = \
			append-tlt-uboot | pad-to $$$$(UBOOT_SIZE) | \
			append-tlt-config | pad-to $$$$(CONFIG_SIZE) | \
			append-tlt-art | pad-to $$$$(ART_SIZE) | \
			append-kernel | pad-to $$$$(BLOCKSIZE) | \
			append-rootfs | pad-rootfs | \
			append-version | \
			check-size $$$$(MASTER_IMAGE_SIZE) | \
			finalize-tlt-master-stendui
endef

define Device/teltonika_trb2m
	$(Device/tlt-mt7628-common)
	IMAGE/master_fw.bin = \
			append-tlt-uboot | pad-to $$$$(UBOOT_SIZE) | \
			append-tlt-config | pad-to $$$$(CONFIG_SIZE) | \
			append-kernel | pad-to $$$$(BLOCKSIZE) | \
			append-rootfs | pad-rootfs | \
			append-version | \
			check-size $$$$(MASTER_IMAGE_SIZE) | \
			finalize-tlt-master-stendui
	DEVICE_MODEL := TRB2M
	DEVICE_BOOT_NAME := tlt-trb2m
	DEVICE_DTS := mt7628an_teltonika_trb2m
	DEVICE_FEATURES += gateway pppmobile gps rs232 rs485 \
			modbus ios single_port dualsim mobile ncm \
			dot1x-server xfrm-offload no-wired-wan tpm port_link

	DEVICE_MTD_LOG_PARTNAME := mtdblock6
	DEVICE_INITIAL_FIRMWARE_SUPPORT := 7.5
	GPL_PREFIX := GPL
	# Default common packages for TRB2M series
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# Essential must-have:
	DEVICE_PACKAGES := kmod-spi-gpio kmod-i2c-mt7628

	# USB related:
	DEVICE_PACKAGES += kmod-usb2 kmod-usb-ohci kmod-usb-ledtrig-usbport \
			kmod-usb-serial-pl2303 kmod-cypress-serial
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	HW_MODS += 246v5 246hwS

	INCLUDED_DEVICES := \
		TEMPLATE_teltonika_trb236 \
		TEMPLATE_teltonika_trb246 \
		TEMPLATE_teltonika_trb247 \
		TEMPLATE_teltonika_trb256 \
		TEMPLATE_teltonika_ntp001

	DEVICE_MODEM_VENDORS := Quectel
	DEVICE_MODEM_LIST := EC25 EG915Q BG95 EG95 EG912N EG950A EG916Q EG21
endef

define Device/teltonika_tap100
	$(Device/tlt-mt7628-common)
	DEVICE_MODEL := TAP100
	DEVICE_BOOT_NAME := tlt-tap100
	DEVICE_DTS := mt7628an_teltonika_tap100
	DEVICE_FEATURES := small_flash access_point single_port wifi ledman-lite dot1x-client no-wired-wan reset_button 64mb_ram

	DEVICE_INITIAL_FIRMWARE_SUPPORT := 7.4
	GPL_PREFIX := GPL
	# Default common packages for TAP100 series
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	# Wireless related:
	DEVICE_PACKAGES += kmod-mt76_515 kmod-mt7603_515
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	INCLUDED_DEVICES := TEMPLATE_teltonika_tap100
endef

define Device/teltonika_otd140
	$(Device/tlt-mt7628-common)
	IMAGE/master_fw.bin = \
			append-tlt-uboot | pad-to $$$$(UBOOT_SIZE) | \
			append-tlt-config | pad-to $$$$(CONFIG_SIZE) | \
			append-kernel | pad-to $$$$(BLOCKSIZE) | \
			append-rootfs | pad-rootfs | \
			check-size $$$$(MASTER_IMAGE_SIZE) | \
			finalize-tlt-master-stendui
	DEVICE_MODEL := OTD140
	DEVICE_BOOT_NAME := tlt-otd140
	DEVICE_DTS := mt7628an_teltonika_otd140
	DEVICE_FEATURES += ncm rndis poe mobile dualsim port_link dot1x-server xfrm-offload \
					   networks_external no-wired-wan tpm

	DEVICE_MTD_LOG_PARTNAME := mtdblock6
	DEVICE_INITIAL_FIRMWARE_SUPPORT := 7.4.4
	GPL_PREFIX := GPL
	# Default common packages for OTD140 series
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# USB related:
	DEVICE_PACKAGES += kmod-usb2 kmod-usb-ohci kmod-i2c-mt7628
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	DEVICE_MODEM_VENDORS := Quectel
	DEVICE_MODEM_LIST := EC200A EC25

	INCLUDED_DEVICES := TEMPLATE_teltonika_otd140
endef

define Device/teltonika_rut14x
	$(Device/tlt-mt7628-common)
	DEVICE_MODEL := RUT14X
	DEVICE_BOOT_NAME := tlt-rut14x
	DEVICE_DTS := mt7628an_teltonika_rut14x
	DEVICE_FEATURES += small_flash rs232 rs485 modbus wifi ledman-lite sw-offload port_link \
	                   dot1x-server xfrm-offload

	DEVICE_INITIAL_FIRMWARE_SUPPORT := 7.6
	GPL_PREFIX := GPL
	# Default common packages for RUT14X series
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	DEVICE_PACKAGES += kmod-usb-ohci kmod-usb-serial-pl2303

	# Wireless related:
	DEVICE_PACKAGES += kmod-mt76_515 kmod-mt7603_515
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	INCLUDED_DEVICES := \
		TEMPLATE_teltonika_rut140 \
		TEMPLATE_teltonika_rut142 \
		TEMPLATE_teltonika_rut145
endef

define Device/teltonika_dap14x
	$(Device/tlt-mt7628-common)
	DEVICE_MODEL := DAP14X
	DEVICE_BOOT_NAME := tlt-dap14x
	DEVICE_DTS := mt7628an_teltonika_dap14x
	DEVICE_FEATURES += small_flash rs232 rs485 modbus wifi ledman-lite sw-offload port_link \
	                   xfrm-offload industrial_access_point no-wired-wan

	# Default common packages for DAP14X series
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	DEVICE_PACKAGES += kmod-usb-ohci kmod-usb-serial-pl2303

	# Wireless related:
	DEVICE_PACKAGES += kmod-mt76_515 kmod-mt7603_515
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	INCLUDED_DEVICES := \
		TEMPLATE_teltonika_dap140 \
		TEMPLATE_teltonika_dap142 \
		TEMPLATE_teltonika_dap145
endef

define Device/teltonika_rut2m
	$(Device/tlt-mt7628-common)
	DEVICE_MODEL := RUT2M
	DEVICE_BOOT_NAME := tlt-rut2m
	DEVICE_DTS := mt7628an_teltonika_rut2m
	DEVICE_FEATURES += ios wifi rndis mobile port_link dualsim dot1x-server xfrm-offload

	GPL_PREFIX := GPL
	# Default common packages for RUT241, RUT200 series
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# USB related:
	DEVICE_PACKAGES += kmod-usb2 kmod-usb-ohci kmod-usb-ledtrig-usbport \
						kmod-i2c-mt7628

	# Wireless related:
	DEVICE_PACKAGES += kmod-mt76_515 kmod-mt7603_515
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	HW_MODS += 260v3 241v5 200v5 ala440

	INCLUDED_DEVICES := \
		TEMPLATE_teltonika_rut200 \
		TEMPLATE_teltonika_rut241 \
		TEMPLATE_teltonika_rut260

	DEVICE_MODEM_VENDORS := Quectel Meiglink Teltonika
	DEVICE_MODEM_LIST := SLM750 EC200A EC25 EG25 SLM828 RG255C ALA440 EG060K
endef

define Device/teltonika_rut301
	$(Device/tlt-mt7628-common)
	IMAGE/master_fw.bin = \
			append-tlt-uboot | pad-to $$$$(UBOOT_SIZE) | \
			append-tlt-config | pad-to $$$$(CONFIG_SIZE) | \
			append-kernel | pad-to $$$$(BLOCKSIZE) | \
			append-rootfs | pad-rootfs | \
			append-version | \
			check-size $$$$(MASTER_IMAGE_SIZE) | \
			finalize-tlt-master-stendui
	DEVICE_MODEL := RUT301
	DEVICE_BOOT_NAME := tlt-rut301
	DEVICE_DTS := mt7628an_teltonika_rut301
	DEVICE_FEATURES += usb-port ios basic-router ledman-lite port_link dot1x-server \
	                   xfrm-offload ntrip

	DEVICE_MTD_LOG_PARTNAME := mtdblock6
	DEVICE_INITIAL_FIRMWARE_SUPPORT := 7.4.1
	GPL_PREFIX := GPL
	# Default common packages for RUT301
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# USB related:
	DEVICE_PACKAGES += kmod-usb2 kmod-usb-ohci
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	INCLUDED_DEVICES := TEMPLATE_teltonika_rut301
endef

define Device/teltonika_rut361
	$(Device/tlt-mt7628-common)
	DEVICE_MODEL := RUT361
	DEVICE_BOOT_NAME := tlt-rut361
	DEVICE_DTS := mt7628an_teltonika_rut361
	DEVICE_FEATURES += ios wifi rndis mobile port_link dot1x-server xfrm-offload

	DEVICE_INITIAL_FIRMWARE_SUPPORT := 7.4.1
	GPL_PREFIX := GPL
	# Default common packages for RUT361
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# USB related:
	DEVICE_PACKAGES += kmod-usb2 kmod-usb-ohci

	# Wireless related:
	DEVICE_PACKAGES += kmod-mt76_515 kmod-mt7603_515
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	DEVICE_MODEM_VENDORS := Quectel
	DEVICE_MODEM_LIST := EG06 EG060K


	INCLUDED_DEVICES := TEMPLATE_teltonika_rut361
endef

define Device/teltonika_rut9m
	$(Device/tlt-mt7628-common)
	DEVICE_MODEL := RUT9M
	DEVICE_BOOT_NAME := tlt-rut9m
	DEVICE_FEATURES += gps usb-port modbus ios wifi dualsim \
			rndis ncm mobile port_link rs232 rs485 dot1x-server port-mirror \
	                xfrm-offload poe ethtool-tiny

	DEVICE_DTS := mt7628an_teltonika_rut9m
	IMAGE_SIZE := 12480k
	GPL_PREFIX := GPL
	# Default common packages for RUT9M series
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# Essential must-have:
	DEVICE_PACKAGES := kmod-spi-gpio kmod-gpio-nxp-74hc164 kmod-i2c-mt7628 \
			kmod-hwmon-mcp3021 kmod-hwmon-tla2021 kmod-cypress-serial

	# USB related:
	DEVICE_PACKAGES += kmod-usb2

	# Wireless related:
	DEVICE_PACKAGES += kmod-mt76_515 kmod-mt7603_515
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	HW_MODS += 2c7c_6005 TLA2021 CH343 esim ala440

	INCLUDED_DEVICES := \
		TEMPLATE_teltonika_rut901 \
		TEMPLATE_teltonika_rut906 \
		TEMPLATE_teltonika_rut951 \
		TEMPLATE_teltonika_rut956

	DEVICE_MODEM_VENDORS := Quectel Meiglink Teltonika
	DEVICE_MODEM_LIST := EC200A SLM770 SLM750 EC25 EG25 RG255C ALA440 EG21
endef

define Device/teltonika_rute
	$(Device/tlt-mt7628-common)

	DEVICE_DTS := \
		mt7628an-teltonika-rut202 \
		mt7628an-teltonika-rut204 \
		mt7628an-teltonika-rut206 \
		mt7628an-teltonika-rut261 \
		mt7628an-teltonika-rut271 \
		mt7628an-teltonika-rut276 \
		mt7628an-teltonika-rut281 \
		mt7628an-teltonika-rut286 \
		mt7628an-teltonika-rut971 \
		mt7628an-teltonika-rut976 \
		mt7628an-teltonika-rut981 \
		mt7628an-teltonika-rut986 \
		mt7628an-teltonika-otd144
	KERNEL := kernel-bin | zstd | fit zstd "$$(KDIR)/{$$(subst $$(space),$$(comma),$$(addprefix image-,$$(addsuffix .dtb,$$(DEVICE_DTS))))}"
	KERNEL_INITRAMFS := $$(KERNEL)

	UBOOT_SIZE := 262144
	IMAGE_SIZE := 30848k
	ART_SIZE := 196608
	MASTER_IMAGE_SIZE := 32768k

	DEVICE_MODEL := RUTE
	DEVICE_BOOT_NAME := tlt-mt7628
	DEVICE_FEATURES := large_flash sw-offload gps modbus ios wifi dualsim \
			rndis ncm mobile port_link rs232 rs485 dot1x-server port-mirror \
			xfrm-offload usb-sd-card usb-port dot1x-client 128mb_ram poe \
			reset_button can-stm tpm

	FILESYSTEMS := squashfs
	GPL_PREFIX := GPL

	IMAGE/master_fw_rut9e.bin = master_fw_custom RUT9M
	IMAGE/master_fw_rut2e.bin = master_fw_custom RUT2M
	IMAGE/master_fw_otd144.bin = master_fw_custom OTD144
	IMAGES += $(if $(CONFIG_BUILD_FACTORY_IMAGE),master_fw_rut9e.bin master_fw_rut2e.bin master_fw_otd144.bin)

	# Default common packages for RUT9E series
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# Essential must-have:
	DEVICE_PACKAGES := kmod-spi-gpio kmod-gpio-nxp-74hc164 kmod-hwmon-mcp3021 \
			kmod-hwmon-tla2021 kmod-cypress-serial kmod-i2c-mt7628 kmod-stm-gpio stm-usb-can

	# USB related:
	DEVICE_PACKAGES += kmod-usb2 kmod-usb-ohci kmod-usb-ledtrig-usbport \
							kmod-usb-serial-pl2303

	# Wireless related:
	DEVICE_PACKAGES += kmod-mt76_515 kmod-mt7603_515
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	INCLUDED_DEVICES := \
		TEMPLATE_teltonika_rut202 \
		TEMPLATE_teltonika_rut204 \
		TEMPLATE_teltonika_rut206 \
		TEMPLATE_teltonika_rut261 \
		TEMPLATE_teltonika_rut271 \
		TEMPLATE_teltonika_rut276 \
		TEMPLATE_teltonika_rut281 \
		TEMPLATE_teltonika_rut286 \
		TEMPLATE_teltonika_rut971 \
		TEMPLATE_teltonika_rut976 \
		TEMPLATE_teltonika_rut981 \
		TEMPLATE_teltonika_rut986 \
		TEMPLATE_teltonika_otd144

	SUPPORTED_DEVICES := teltonika,rute teltonika,rut202 teltonika,rut204 teltonika,rut206 teltonika,rut261 \
						 teltonika,rut271 teltonika,rut276 teltonika,rut281 teltonika,rut286 teltonika,rut971 teltonika,rut976 \
						 teltonika,rut981 teltonika,rut986 teltonika,otd144

	DEVICE_MODEM_VENDORS := Quectel Telit Teltonika
	DEVICE_MODEM_LIST := EC200A EC25 EG060W RG255C LE910C4 ALA440 FE910C4
endef
TARGET_DEVICES += teltonika_rute

