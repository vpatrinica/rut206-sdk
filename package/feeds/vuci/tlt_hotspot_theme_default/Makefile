include $(TOPDIR)/rules.mk

THEME_NAME=default
PKG_NAME:=hs_theme_$(THEME_NAME)
PKG_VERSION:=2022-07-27
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_LICENSE:=Teltonika-nda-source

include $(INCLUDE_DIR)/package.mk


define Package/tlt_hs_theme_$(THEME_NAME)
	SECTION:=webui
	CATEGORY:=WebUI
	SUBMENU:=Landing page themes
	TITLE:=Default theme
	DEPENDS:=+vuci-app-landingpage
endef

define Package/tlt_hs_theme_$(THEME_NAME)/description
	Hotspot landing page default theme.
endef



define Package/tlt_hs_theme_$(THEME_NAME)/install
	$(INSTALL_DIR) $(1)/etc/chilli/hotspotlogin
	$(CP) files/etc/chilli/hotspotlogin/* $(1)/etc/chilli/hotspotlogin/

	$(INSTALL_DIR) $(1)/etc/permtab.d
	echo "/etc/chilli/hotspotlogin/skins/$(THEME_NAME)             chilli:chilli      664      r" > $(1)/etc/permtab.d/hs_theme_$(THEME_NAME)
	echo "/etc/chilli/hotspotlogin/skins/$(THEME_NAME)             chilli:chilli      774      -" >> $(1)/etc/permtab.d/hs_theme_$(THEME_NAME)
	echo "/etc/chilli/hotspotlogin/skins/$(THEME_NAME)/img         chilli:chilli      774      -" >> $(1)/etc/permtab.d/hs_theme_$(THEME_NAME)
	echo "" >> $(1)/etc/permtab.d/hs_theme_$(THEME_NAME)
endef

$(eval $(call BuildPackage,tlt_hs_theme_$(THEME_NAME)))
