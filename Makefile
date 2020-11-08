include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-v2fly
PKG_VERSION:=v4.32.1
PKG_RELEASE:=2

PKG_LICENSE:=GPLv3
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=yichya <mail@yichya.dev>

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=Custom
	CATEGORY:=Extra packages
	TITLE:=LuCI Support for V2Fly
	DEPENDS:=+iptables +ca-bundle +luci-compat
endef

define Package/$(PKG_NAME)/description
	LuCI Support for V2Fly (Client-side Rendered).
endef

define Package/$(PKG_NAME)/config
menu "V2Fly Configuration"
	depends on PACKAGE_$(PKG_NAME)

config PACKAGE_V2FLY_INCLUDE_V2RAY
	bool "Include v2ray"
	default y

config PACKAGE_V2FLY_SOFTFLOAT
	bool "Use soft-float binaries (mips/mipsle only)"
	depends on mipsel || mips || mips64el || mips64
	default n

config PACKAGE_V2FLY_INCLUDE_V2CTL
	bool "Include v2ctl"
	depends on PACKAGE_V2FLY_INCLUDE_V2RAY
	default y

config PACKAGE_V2FLY_INCLUDE_GEOIP
	bool "Include geoip.dat"
	depends on PACKAGE_V2FLY_INCLUDE_V2RAY
	default n

config PACKAGE_V2FLY_INCLUDE_GEOSITE
	bool "Include geosite.dat"
	depends on PACKAGE_V2FLY_INCLUDE_V2RAY
	default n

config PACKAGE_V2FLY_INCLUDE_CLOUDFLARE_ORIGIN_ROOT_CA
	bool "Include Cloudflare Origin Root CA"
	depends on PACKAGE_V2FLY_INCLUDE_V2RAY
	default n

endmenu
endef

ifeq ($(ARCH),x86_64)
	PKG_ARCH_V2FLY:=linux-64
endif
ifeq ($(ARCH),mipsel)
	PKG_ARCH_V2FLY:=linux-mipsle
endif
ifeq ($(ARCH),mips)
	PKG_ARCH_V2FLY:=linux-mips
endif
ifeq ($(ARCH),i386)
	PKG_ARCH_V2FLY:=linux-32
endif
ifeq ($(ARCH),arm)
	PKG_ARCH_V2FLY:=linux-arm
endif
ifeq ($(ARCH),aarch64)
	PKG_ARCH_V2FLY:=linux-arm64
endif

V2RAY_BIN:=v2ray
V2CTL_BIN:=v2ctl

ifeq ($(ARCH),arm)
	ifneq ($(BOARD),bcm53xx)
		V2RAY_BIN:=v2ray_armv7
		V2CTL_BIN:=v2ctl_armv7
	endif
endif

ifdef CONFIG_PACKAGE_V2FLY_SOFTFLOAT
	V2RAY_BIN:=v2ray_softfloat
	V2CTL_BIN:=v2ctl_softfloat
endif

define Build/Prepare
	$(foreach po,$(wildcard ${CURDIR}/files/luci/i18n/*.po), po2lmo $(po) $(PKG_BUILD_DIR)/$(patsubst %.po,%.lmo,$(notdir $(po)));)
	[ ! -f $(PKG_BUILD_DIR)/v2ray-$(PKG_VERSION)-$(PKG_ARCH_V2FLY).zip ] && proxychains wget https://github.com/v2fly/v2ray-core/releases/download/$(PKG_VERSION)/v2ray-$(PKG_ARCH_V2FLY).zip -O $(PKG_BUILD_DIR)/v2ray-$(PKG_VERSION)-$(PKG_ARCH_V2FLY).zip
	unzip -o $(PKG_BUILD_DIR)/v2ray-$(PKG_VERSION)-$(PKG_ARCH_V2FLY).zip -d $(PKG_BUILD_DIR)
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
	if [[ -f /etc/uci-defaults/luci-v2fly ]]; then
		( . /etc/uci-defaults/luci-v2fly ) && \
		rm -f /etc/uci-defaults/luci-v2fly
	fi
	rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
fi
exit 0
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/v2fly
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/share/v2fly
	$(INSTALL_DIR) $(1)/usr/bin
ifdef CONFIG_PACKAGE_V2FLY_INCLUDE_V2RAY
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/$(V2RAY_BIN) $(1)/usr/bin/v2ray
endif
ifdef CONFIG_PACKAGE_V2FLY_INCLUDE_V2CTL
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/$(V2CTL_BIN) $(1)/usr/bin/v2ctl
endif
	$(INSTALL_DIR) $(1)/etc/ssl/certs
ifdef CONFIG_PACKAGE_V2FLY_INCLUDE_CLOUDFLARE_ORIGIN_ROOT_CA
	$(INSTALL_DATA) ./root/etc/ssl/certs/origin_ca_ecc_root.pem $(1)/etc/ssl/certs/origin_ca_ecc_root.pem
endif
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/v2fly $(1)/etc/init.d/v2fly
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./root/etc/uci-defaults/v2fly $(1)/etc/uci-defaults/v2fly
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view
	$(INSTALL_DATA) ./root/www/luci-static/resources/view/v2fly.js $(1)/www/luci-static/resources/view/v2fly.js
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-v2fly.json $(1)/usr/share/luci/menu.d/luci-app-v2fly.json
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-v2fly.json $(1)/usr/share/rpcd/acl.d/luci-app-v2fly.json
	$(INSTALL_DIR) $(1)/usr/share/v2fly
ifdef CONFIG_PACKAGE_V2FLY_INCLUDE_GEOIP
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/geoip.dat $(1)/usr/share/v2fly/
endif
ifdef CONFIG_PACKAGE_V2FLY_INCLUDE_GEOSITE
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/geosite.dat $(1)/usr/share/v2fly/
endif
	$(INSTALL_BIN) ./root/usr/share/v2fly/gen_config.lua $(1)/usr/share/v2fly/gen_config.lua
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
