include $(TOPDIR)/rules.mk

APP_TITLE:=VuCI UI Support for DMVPN
APP_DEPENDS:=+vuci-app-dynamic-routes-nhrp-ui

include ../app.mk

define Package/vuci-app-dmvpn-ui/description
	Dynamic Multipoint VPN (DMVPN) is a method of building scalable IPsec VPNs.
	DMVPN is configured as a hub-and-spoke network, where tunnels between spokes
	are built dynamically; therefore, no change in configuration is required on
	the hub in order to connect new spokes.
endef

# call BuildPackage - OpenWrt buildroot signature
