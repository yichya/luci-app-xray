include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-xray
PKG_VERSION:=7da97635b28bfa7296fe79bbe7cd804a684317d9
PKG_RELEASE:=2

PKG_LICENSE:=MPLv2
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=yichya <mail@yichya.dev>

PKG_SOURCE:=Xray-core-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/XTLS/Xray-core/tar.gz/${PKG_VERSION}?
PKG_HASH:=2f1f233112f3de11bfa119a63fe7af21d6d8e803ff6d761e3b4284a143914b42
PKG_SOURCE_VERSION:=7da97635b28bfa7296fe79bbe7cd804a684317d9

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1

GO_PKG:=github.com/XTLS/Xray-core

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/../feeds/packages/lang/golang/golang-package.mk

define Package/$(PKG_NAME)
	SECTION:=Custom
	CATEGORY:=Extra packages
	TITLE:=LuCI Support for Xray
	DEPENDS:=$(GO_ARCH_DEPENDS) +iptables +iptables-mod-tproxy +ca-bundle
endef

define Package/$(PKG_NAME)/description
	LuCI Support for Xray (Client-side Rendered).
endef

define Package/$(PKG_NAME)/config
menu "Xray Configuration"
	depends on PACKAGE_$(PKG_NAME)

config PACKAGE_XRAY_FETCH_VIA_PROXYCHAINS
	bool "Fetch data files using proxychains (not recommended)"
	default n

config PACKAGE_XRAY_INCLUDE_XRAY
	bool "Include xray"
	default y

config PACKAGE_XRAY_INCLUDE_GEOIP
	bool "Include geoip.dat"
	depends on PACKAGE_XRAY_INCLUDE_XRAY
	default n

config PACKAGE_XRAY_INCLUDE_GEOSITE
	bool "Include geosite.dat"
	depends on PACKAGE_XRAY_INCLUDE_XRAY
	default n

config PACKAGE_XRAY_INCLUDE_CLOUDFLARE_ORIGIN_ROOT_CA
	bool "Include Cloudflare Origin Root CA"
	depends on PACKAGE_XRAY_INCLUDE_XRAY
	default n

endmenu
endef

PROXYCHAINS:=

ifdef CONFIG_PACKAGE_XRAY_FETCH_VIA_PROXYCHAINS
	PROXYCHAINS:=proxychains
endif

MAKE_PATH:=$(GO_PKG_WORK_DIR_NAME)/build/src/$(GO_PKG)
MAKE_VARS += $(GO_PKG_VARS)

define Build/Patch
	$(CP) $(PKG_BUILD_DIR)/../Xray-core-$(PKG_VERSION)/* $(PKG_BUILD_DIR)
endef

define Build/Compile
	cd $(PKG_BUILD_DIR)/main; $(GO_PKG_VARS) GOPROXY=https://goproxy.io,direct CGO_ENABLED=0 go build -o $(PKG_INSTALL_DIR)/bin/xray .; 
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
if [[ -z "$${IPKG_INSTROOT}" ]]; then
	if [[ -f /etc/uci-defaults/xray ]]; then
		( . /etc/uci-defaults/xray ) && rm -f /etc/uci-defaults/xray
	fi
	rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
fi
exit 0
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/xray
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./root/usr/bin/transparent-proxy-rules $(1)/usr/bin/transparent-proxy-rules
ifdef CONFIG_PACKAGE_XRAY_INCLUDE_XRAY
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/bin/xray $(1)/usr/bin/xray
endif
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/xray $(1)/etc/config/xray
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./root/etc/hotplug.d/iface/01-transparent-proxy $(1)/etc/hotplug.d/iface/01-transparent-proxy
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/xray $(1)/etc/init.d/xray
	$(INSTALL_DIR) $(1)/etc/ssl/certs
ifdef CONFIG_PACKAGE_XRAY_INCLUDE_CLOUDFLARE_ORIGIN_ROOT_CA
	$(INSTALL_DATA) ./root/etc/ssl/certs/origin_ca_ecc_root.pem $(1)/etc/ssl/certs/origin_ca_ecc_root.pem
endif
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./root/etc/uci-defaults/xray $(1)/etc/uci-defaults/xray
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view
	$(INSTALL_DATA) ./root/www/luci-static/resources/view/xray.js $(1)/www/luci-static/resources/view/xray.js
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-xray.json $(1)/usr/share/luci/menu.d/luci-app-xray.json
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-xray.json $(1)/usr/share/rpcd/acl.d/luci-app-xray.json
	$(INSTALL_DIR) $(1)/usr/share/xray
	$(INSTALL_BIN) ./root/usr/share/xray/gen_config.lua $(1)/usr/share/xray/gen_config.lua
ifdef CONFIG_PACKAGE_XRAY_INCLUDE_GEOIP
	$(PROXYCHAINS) wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O $(PKG_BUILD_DIR)/geoip.dat
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/geoip.dat $(1)/usr/share/xray/
endif
ifdef CONFIG_PACKAGE_XRAY_INCLUDE_GEOSITE
	$(PROXYCHAINS) wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O $(PKG_BUILD_DIR)/geosite.dat
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/geosite.dat $(1)/usr/share/xray/
endif
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
