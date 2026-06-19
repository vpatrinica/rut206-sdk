include $(TOPDIR)/rules.mk

PKG_NAME:=libcotp

PKG_VERSION:=1.1.1
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_URL:=https://codeload.github.com/tilkinsc/COTP/tar.gz/v$(PKG_VERSION)?
PKG_HASH:=07741d992b35d588f9a61ac886a2fc451cb496e30c90d112f759f6b3d31c4048

PKG_SOURCE_VERSION:=v$(PKG_VERSION)

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/libcotp
	SECTION:=libs
	CATEGORY:=Libraries
	TITLE:=A simple One Time Password (OTP) library
	DEPENDS:=+libopenssl
endef

define Package/libcotp/description
	A simple One Time Password (OTP) library in C
endef

define Build/Compile
    $(MAKE) -C $(PKG_BUILD_DIR) \
        CC="$(TARGET_CC)" \
        CXX="$(TARGET_CXX)" \
        AR="$(TARGET_AR)" \
        c_compiler="$(TARGET_CC)" \
        cpp_compiler="$(TARGET_CXX)" \
        cmd_ar="$(TARGET_AR)" \
        c_flags="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS) -fPIC" \
        c_ldflags="$(TARGET_LDFLAGS) -shared" \
        libs
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	$(CP) $(PKG_BUILD_DIR)/*.h $(1)/usr/include/
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/libcotp.{a,so*} $(1)/usr/lib/
endef

define Package/libcotp/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/libcotp.so* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libcotp))
