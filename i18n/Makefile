include $(TOPDIR)/rules.mk

PKG_NAME:=luci-i18n-xray-zh-cn
PKG_VERSION:=3.7.1
PKG_RELEASE:=1

PKG_LICENSE:=MPLv2
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=yichya <mail@yichya.dev>
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=luci
	CATEGORY:=LuCI
	TITLE:=LuCI Support for Xray - Chinese (Simplified)
	DEPENDS:=luci-app-xray
	PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
	LuCI Support for Xray (Client-side Rendered) - Chinese (Simplified) translation.
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	po2lmo ./po/zh_Hans/xray.po $(1)/usr/lib/lua/luci/i18n/xray.zh-cn.lmo
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
