# luci-app-xray

[luci-app-v2ray](https://github.com/yichya/luci-app-v2ray) refined to client side rendering (and switched to xray as well)

## Changelog

* 2020-11-14 feature: basic transparent proxy function
* 2020-11-15 fix: vless flow settings & compatible with busybox ip command
* 2020-12-04 feature: add xtls-rprx-splice to flow
* 2020-12-26 feature: allow to determine whether to use proxychains during build; trojan xtls flow settings
* 2021-01-01 feature: build xray from source; various fixes about tproxy and logging

## Todo

* [x] LuCI ACL Settings
* [x] migrate to xray-core
* [ ] Xray Running Status Check
* [ ] transparent proxy access control for LAN
