include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-xray
PKG_VERSION:=v1.1.2
PKG_RELEASE:=1

PKG_LICENSE:=GPLv3
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=yichya <mail@yichya.dev>

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=Custom
	CATEGORY:=Extra packages
	TITLE:=LuCI Support for Xray
	DEPENDS:=+iptables +iptables-mod-tproxy +ca-bundle
endef

define Package/$(PKG_NAME)/description
	LuCI Support for Xray (Client-side Rendered).
endef

define Package/$(PKG_NAME)/config
menu "Xray Configuration"
	depends on PACKAGE_$(PKG_NAME)

config PACKAGE_XRAY_INCLUDE_XRAY
	bool "Include xray"
	default y

config PACKAGE_XRAY_SOFTFLOAT
	bool "Use soft-float binaries (mips/mipsle only)"
	depends on mipsel || mips || mips64el || mips64
	default n

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

ifeq ($(ARCH),x86_64)
	PKG_ARCH_XRAY:=linux-64
endif
ifeq ($(ARCH),mipsel)
	PKG_ARCH_XRAY:=linux-mipsle
endif
ifeq ($(ARCH),mips)
	PKG_ARCH_XRAY:=linux-mips
endif
ifeq ($(ARCH),i386)
	PKG_ARCH_XRAY:=linux-32
endif
ifeq ($(ARCH),arm)
	PKG_ARCH_XRAY:=linux-arm
endif
ifeq ($(ARCH),aarch64)
	PKG_ARCH_XRAY:=linux-arm64
endif

XRAY_BIN:=xray

ifeq ($(ARCH),arm)
	ifneq ($(BOARD),bcm53xx)
		XRAY_BIN:=xray_armv7
	endif
endif

ifdef CONFIG_PACKAGE_XRAY_SOFTFLOAT
	XRAY_BIN:=xray_softfloat
endif

define Build/Prepare
	$(foreach po,$(wildcard ${CURDIR}/files/luci/i18n/*.po), po2lmo $(po) $(PKG_BUILD_DIR)/$(patsubst %.po,%.lmo,$(notdir $(po)));)
	[ ! -f $(PKG_BUILD_DIR)/XRAY-$(PKG_VERSION)-$(PKG_ARCH_XRAY).zip ] && proxychains wget https://github.com/xtls/xray-core/releases/download/$(PKG_VERSION)/xray-$(PKG_ARCH_XRAY).zip -O $(PKG_BUILD_DIR)/xray-$(PKG_VERSION)-$(PKG_ARCH_XRAY).zip
	unzip -o $(PKG_BUILD_DIR)/xray-$(PKG_VERSION)-$(PKG_ARCH_XRAY).zip -d $(PKG_BUILD_DIR)
	proxychains wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O $(PKG_BUILD_DIR)/geoip.dat
	proxychains wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O $(PKG_BUILD_DIR)/geosite.dat
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
if [[ -z "$${IPKG_INSTROOT}" ]]; then
	if [[ -f /etc/uci-defaults/luci-xray ]]; then
		( . /etc/uci-defaults/luci-xray ) && \
		rm -f /etc/uci-defaults/luci-xray
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
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/$(XRAY_BIN) $(1)/usr/bin/xray
endif
	$(INSTALL_DIR) $(1)/etc/ssl/certs
ifdef CONFIG_PACKAGE_XRAY_INCLUDE_CLOUDFLARE_ORIGIN_ROOT_CA
	$(INSTALL_DATA) ./root/etc/ssl/certs/origin_ca_ecc_root.pem $(1)/etc/ssl/certs/origin_ca_ecc_root.pem
endif
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./root/etc/hotplug.d/iface/01-transparent-proxy $(1)/etc/hotplug.d/iface/01-transparent-proxy
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/xray $(1)/etc/init.d/xray
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
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/geoip.dat $(1)/usr/share/xray/
endif
ifdef CONFIG_PACKAGE_XRAY_INCLUDE_GEOSITE
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/geosite.dat $(1)/usr/share/xray/
endif
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
