# luci-app-xray

Focus on making the most of Xray (HTTP/HTTPS/Socks/TProxy inbounds, multiple protocols support, DNS server, bridge (reverse proxy), even HTTPS proxy server for actual HTTP services) while keeping thin and elegant.

## Warnings

* Since version 3.2.0 sniffing and global custom settings are deprecated. 
    * These features are moved out of main luci app. Select "Preview or Deprecated" in "Extra Settings" tab and reboot to let those settings show again in preview app.
    * These likely to be removed in version 4.0.0. Use FakeDNS instead of sniffing and use "Custom Configuration Hook" for global custom settings. 
* This project **DOES NOT SUPPORT** the following versions of OpenWrt because of the requirements of firewall4 and cilent-side rendering LuCI:
    * LEDE / OpenWrt prior to 22.03
    * [Lean's OpenWrt Source](https://github.com/coolsnowwolf/lede) (which uses a variant of LuCI shipped with OpenWrt 18.06)

    If this is your case, use Passwall or similar projects instead (you could find links in [XTLS/Xray-core](https://github.com/XTLS/Xray-core/)).
* About experimental REALITY support
    * it may change quite frequently (before the release of official documents about the protocol). Keep in mind for (maybe) breaking changes.
* If you see `WARNING: at least one of asset files (geoip.dat, geosite.dat) is not found under /usr/share/xray. Xray may not work properly` and don't know what to do:
    * try `opkg update && opkg install v2ray-geoip v2ray-geosite`
    * if that doesn't work, see [#52](https://github.com/yichya/luci-app-xray/issues/52#issuecomment-856059905)
* This project may change its code structure, configuration files format, user interface or dependencies quite frequently since it is still in its very early stage. 

## Installation (Manually building OpenWrt)

Choose one below:

* Add `src-git-full luci_app_xray https://github.com/yichya/luci-app-xray` to `feeds.conf.default` and run `./scripts/feeds update -a; ./scripts/feeds install -a` 
* Clone this repository under `package`

Then find `luci-app-xray` under `Extra Packages`.

## Installation (Use GitHub actions to build ipks)

Fork this repository and:

* Create a release by pushing a tag
* Wait until actions finish
* Use `opkg -i *` to install both ipks from Releases.

## Changelog since 3.2.0

* 2023-12-20 chore: bump version
* 2023-12-22 chore: optimize list folded format; add roundRobin balancer
* 2024-01-04 chore: start later than sysntpd; change firewall include file path
* 2024-01-18 feat: make "Resolve Domain via DNS" available to all outbounds

## Changelog since 3.1.0

* 2023-10-24 chore: bump version
* 2023-10-25 fix: set required for some fields; remove unused code
* 2023-10-26 fix: allow empty selection for extra inbound outbound balancer
* 2023-10-30 fix: blocked as nxdomain for IPv6
* 2023-10-31 chore: bump version to 3.1.1
* 2023-11-01 feat: custom configuration hook
* 2023-11-02 feat: specify DNS to resolve outbound server name
* 2023-11-30 fix: dialer proxy tag
* 2023-12-14 fix: default gateway
* 2023-12-20 chore: deprecate sniffing; move some preview features to main app; add custom configuration hook; refactor web files

## Changelog since 3.0.0

* 2023-09-26 Version 3.0.0 merge master
* 2023-09-27 fix: sniffing inboundTag; fix: upstream_domain_names
* 2023-10-01 fix: default configuration
* 2023-10-06 chore: code cleanup
* 2023-10-19 feat: detailed status page via metrics
* 2023-10-20 feat: better network interface control. **Requires reselection of LAN interfaces in** `Xray (preview)` -> `LAN Hosts Access Control`

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=yichya/luci-app-xray&type=Date)](https://star-history.com/#yichya/luci-app-xray&Date)
