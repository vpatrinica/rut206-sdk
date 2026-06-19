define Package/base-files/install-target

	# set log partition
	$(SED) "s#%%LOG_PARTITION%%#$(CONFIG_DEVICE_MTD_LOG_PARTNAME)#g" $(1)/etc/fstab

	if [ -e "$(PLATFORM_DIR)/teltonika/sysctl.d/10-default.conf-$(call device_shortname)" ]; then \
		$(CP) $(PLATFORM_DIR)/teltonika/sysctl.d/10-default.conf-$(call device_shortname) $(1)/etc/sysctl.d/10-default.conf; \
	fi;

endef
