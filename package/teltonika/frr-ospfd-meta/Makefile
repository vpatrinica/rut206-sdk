include $(TOPDIR)/rules.mk

PKG_NAME:=frr-ospfd-meta
PKG_VERSION:=2026-01-21
PKG_RELEASE:=1
PKG_LICENSE:=Teltonika-closed

include $(INCLUDE_DIR)/package.mk

define Package/frr-ospfd-meta
	SECTION:=net
	CATEGORY:=Network
	TITLE:=FRR ospfd service meta package
	DEPENDS:=+vuci-app-dynamic-routes-ospf-ui
	ifneq (,$(filter m,$(CONFIG_PACKAGE_frr-ospfd-meta))$(DUMP))
		PKG_TLT_NAME:=OSPF daemon
		PKG_ROUTER:=$(TLT_PLATFORM_NAME)
		PKG_APP_NAME:=frr-ospfd
	endif
endef

define Package/frr-ospfd-meta/description
	Open Shortest Path First (OSPF) is a routing protocol
	for Internet Protocol (IP) networks. It uses a link state
	routing (LSR) algorithm and falls into the group of interior
	gateway protocols (IGPs), operating within a single autonomous system (AS).
endef

define Package/frr-ospfd-meta/prerm
	#!/bin/sh

	. /lib/functions.sh

	# Delete all OSPF firewall rules
	delete_ospf_rules() {
		local section="$$1"
		local name

		config_get name "$$section" name

		if [ -n "$$name" ] && echo "$$name" | grep -q "^Allow-OSPFIGP-"; then
			uci_remove firewall "$$section"
		fi
	}

	config_load firewall
	config_foreach delete_ospf_rules rule
	uci_commit "firewall"
	/etc/init.d/firewall reload > /dev/null 2>&1
endef



define Package/frr-ospfd-meta/install
	$(INSTALL_DIR) $(1)/usr/share/vuci/menu.d/
	$(LN) /usr/local/usr/share/vuci/menu.d/routes_ospf.json $(1)/usr/share/vuci/menu.d/routes_ospf_link.json
endef

$(eval $(call BuildPackage,frr-ospfd-meta))
