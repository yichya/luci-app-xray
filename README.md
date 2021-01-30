# luci-app-xray

[luci-app-v2ray](https://github.com/yichya/luci-app-v2ray) refined to client side rendering (and switched to xray as well).

Focus on making the most of Xray (HTTP/HTTPS/Socks/TProxy inbounds, multiple protocols support, DNS server, even HTTPS reverse proxy server for actual HTTP services) while keeping thin and elegant.

## Warnings

* This project **DOES NOT SUPPORT** LEDE 17.01 releases or OpenWrt 18.06 releases (including some old [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) versions) due to the fact that client side rendering requires LuCI client side apis shipped with OpenWrt 19.07 releases. If this is your case, use Passwall or similar projects instead (you could find links in [XTLS/Xray-core](https://github.com/XTLS/Xray-core/)).
* For OpenWrt 19.07 releases, you need to prepare your own xray-core package (just download from [Releases · yichya/openwrt-xray](https://github.com/yichya/openwrt-xray/releases) and install that) because building Xray from source requires Go 1.15 which is currently only available in OpenWrt SNAPSHOT.
* This project may change its code structure, configuration files format, user interface or dependencies quite frequently since it is still in its very early stage. 

## Changelog

* 2020-11-14 feature: basic transparent proxy function
* 2020-11-15 fix: vless flow settings & compatible with busybox ip command
* 2020-12-04 feature: add xtls-rprx-splice to flow
* 2020-12-26 feature: allow to determine whether to use proxychains during build; trojan xtls flow settings
* 2021-01-01 feature: build xray from source; various fixes about tproxy and logging
* 2021-01-25 feature: xray act as HTTPS server
* 2021-01-29 fix: add ipset as dependency to fix transparent proxy problems; remove useless and faulty extra_command in init.d script
* 2021-01-29 feature: decouple with xray original binary and data files. Use any xray-core provider package like [openwrt-xray](https://github.com/yichya/openwrt-xray) or [packages#14598](https://github.com/openwrt/packages/pull/14598) (if that got merged).
* 2021-01-30 feature: select GeoIP set for direct connection. This is considered a **BREAKING** change because if unspecified, all IP addresses is forwarded through Xray.

## Todo

* [x] LuCI ACL Settings
* [x] migrate to xray-core
* [ ] better server role configurations
* [ ] Xray Running Status Check
* [ ] transparent proxy access control for LAN
