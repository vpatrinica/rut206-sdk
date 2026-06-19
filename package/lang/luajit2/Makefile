include $(TOPDIR)/rules.mk

PKG_NAME:=luajit2
PKG_SOURCE_DATE:=2025-05-29
PKG_VERSION:=2.1.$(subst -,.,$(PKG_SOURCE_DATE))
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/LuaJIT/LuaJIT
PKG_SOURCE_VERSION:=4b90f6c4d7420139c135435e1580acb52ea18436
PKG_MIRROR_HASH:=098d0d7557d619465cad08e8d2e6df60e4304668d4c777ad87c24c26431490d2

PKG_MAINTAINER:=Morteza Milani <milani@pichak.co>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=COPYRIGHT
PKG_CPE_ID:=cpe:/a:luajit:luajit

PKG_BUILD_FLAGS:=no-mips16

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/host-build.mk

define Package/luajit2
 SUBMENU:=Lua
 SECTION:=lang
 CATEGORY:=Languages
 TITLE:=LuaJIT
 URL:=https://www.luajit.org
 DEPENDS:=@(i386||x86_64||arm||armeb||aarch64||powerpc||mips||mipsel||mips64)
 PROVIDES=luajit
endef

define Package/luajit2/description
 LuaJIT is a Just-In-Time (JIT) compiler for the Lua programming language.
endef

ifeq ($(HOST_ARCH),$(filter $(HOST_ARCH), x86_64 mips64))
  ifeq ($(CONFIG_ARCH_64BIT),)
    HOST_BITS := -m32
  endif
endif

define Build/Compile
	$(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR) \
		HOST_CC="$(HOSTCC) $(HOST_CFLAGS) $(HOST_BITS)" \
		CROSS="$(TARGET_CROSS)" \
		DESTDIR=$(PKG_INSTALL_DIR) \
		PREFIX=/usr \
		TARGET_SYS=Linux \
		TARGET_CFLAGS="$(TARGET_CFLAGS)" \
		XCFLAGS="-DLUAJIT_DISABLE_FFI -DLUAJIT_DISABLE_PROFILE -DLUAJIT_DISABLE_BUFFER" \
		BUILDMODE=dynamic \
		amalg
	$(RM) -rf $(PKG_INSTALL_DIR)
	mkdir -p $(PKG_INSTALL_DIR)
	$(MAKE) -C $(PKG_BUILD_DIR) \
		DESTDIR=$(PKG_INSTALL_DIR) \
		PREFIX=/usr \
		TARGET_SYS=Linux \
		install
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/luajit-2.1
	$(CP) $(PKG_INSTALL_DIR)/usr/include/luajit-2.1/*.{h,hpp} $(1)/usr/include/luajit-2.1
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/*so* $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/lib/pkgconfig
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/pkgconfig/luajit.pc $(1)/usr/lib/pkgconfig/
	$(INSTALL_DIR) $(1)/usr/bin
	$(CP) $(PKG_INSTALL_DIR)/usr/bin/luajit-* $(1)/usr/bin/luajit
endef

define Package/luajit2/install
	$(INSTALL_DIR) $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/*.so* $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/bin
	$(CP) $(PKG_INSTALL_DIR)/usr/bin/luajit-* $(1)/usr/bin/luajit
	$(LN) luajit $(1)/usr/bin/lua
endef

define Host/Compile
	$(MAKE) $(HOST_JOBS) -C $(HOST_BUILD_DIR) \
		PREFIX=$(STAGING_DIR_HOSTPKG) \
		TARGET_CFLAGS="$(HOST_CFLAGS)" \
		TARGET_LDFLAGS="$(HOST_LDFLAGS)"
endef

define Host/Install
	$(MAKE) $(HOST_JOBS) -C $(HOST_BUILD_DIR) \
		PREFIX=$(STAGING_DIR_HOSTPKG) \
		install

	mv $(STAGING_DIR_HOSTPKG)/bin/luajit-* $(STAGING_DIR_HOSTPKG)/bin/luajit
endef

$(eval $(call HostBuild,luajit2))
$(eval $(call BuildPackage,luajit2))
