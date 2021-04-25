include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-xray
PKG_VERSION:=1.0.8
PKG_RELEASE:=3

PKG_LICENSE:=MPLv2
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=yichya <mail@yichya.dev>

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=Custom
	CATEGORY:=Extra packages
	TITLE:=LuCI Support for Xray
	DEPENDS:=+luci-base +openwrt-xray +dnsmasq +ipset +firewall +iptables +iptables-mod-tproxy +ca-bundle
	CONFLICTS:=xray-core
endef

define Package/$(PKG_NAME)/description
	LuCI Support for Xray (Client-side Rendered).
endef

define Package/$(PKG_NAME)/config
menu "luci-app-xray Configuration"
	depends on PACKAGE_$(PKG_NAME)

config PACKAGE_XRAY_INCLUDE_CLOUDFLARE_ORIGIN_ROOT_CA
	bool "Include Cloudflare Origin Root CA"
	default n

endmenu
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
if [[ -z "$${IPKG_INSTROOT}" ]]; then
	if [[ -f /etc/uci-defaults/xray ]]; then
		( . /etc/uci-defaults/xray ) && rm -f /etc/uci-defaults/xray
	fi
	rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache
fi
exit 0
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/xray
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./root/usr/bin/transparent-proxy-ipset $(1)/usr/bin/transparent-proxy-ipset
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/xray $(1)/etc/config/xray
	$(INSTALL_DIR) $(1)/etc/luci-uploads/xray
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
	$(INSTALL_BIN) ./root/usr/share/xray/firewall_include.lua $(1)/usr/share/xray/firewall_include.lua
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
