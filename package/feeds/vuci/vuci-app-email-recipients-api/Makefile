include $(TOPDIR)/rules.mk

APP_TITLE:=VuCI API Support for Email Recipients
CUSTOM_INSTALL=1

include ../api.mk


define Package/$(PKG_NAME)/install
	$(call Package/$(PKG_NAME)/install/Default,$(1))
	$(INSTALL_DIR) $(1)/etc/permtab.d $(1)/etc/config
	$(CP) ./distro/recipients.permtab $(1)/etc/permtab.d/recipients
	$(CP) ./distro/user_groups.config $(1)/etc/config/user_groups
endef

# call BuildPackage - OpenWrt buildroot signature
$(eval $(call BuildPackage,$(PKG_NAME)))
