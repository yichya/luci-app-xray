'use strict';
'require view';
'require uci';
'require form';


return view.extend({
    load: function () {
        return L.uci.load("xray")
    },

    render: function (config_data) {
        var m, s, o;
        m = new form.Map('xray', [_('Xray')]);

        s = m.section(form.TypedSection, 'general', 'General Settings',);
        s.addremove = false;
        s.anonymous = true;

        s.tab('general', _('General Settings'));

        o = s.taboption('general', form.Value, 'xray_bin', _('Xray Executable Path'))

        o = s.taboption('general', form.ListValue, 'main_server', _('Main Server'))
        for (var v of L.uci.sections(config_data, "servers")) {
            o.value(v[".name"], v.alias || v.server + ":" + v.server_port)
        }

        o = s.taboption('general', form.Flag, 'transparent_proxy_enable', _('Enable Transparent Proxy'))

        o = s.taboption('general', form.Flag, 'transparent_proxy_udp', _('Transparent Proxy for UDP'))
        o.depends("transparent_proxy_enable", "1")

        s.tab('proxy', _('Proxy Settings'));

        o = s.taboption('proxy', form.Value, 'tproxy_port', _('Transparent Proxy Port'))
        o.datatype = 'port'
        o.default = 1081

        o = s.taboption('proxy', form.Value, 'http_port', _('Http Proxy Port'))
        o.datatype = 'port'
        o.default = 1082

        o = s.taboption('proxy', form.Value, 'socks_port', _('Socks5 Proxy Port'))
        o.datatype = 'port'
        o.default = 5000

        o = s.taboption('proxy', form.Value, 'dns_port', _('Xray DNS Server Port'))
        o.datatype = 'port'
        o.default = 5000

        o = s.taboption('proxy', form.Value, 'mark', _('Socket Mark Number'), _('Avoid proxy loopback problems with local (gateway) traffic'))
        o.datatype = 'range(1, 255)'
        o.default = 255

        s.tab('dns', _('DNS Settings'));

        o = s.taboption('dns', form.Value, 'fast_dns', _('Fast DNS'), _("DNS for resolving geosite:cn sites"))
        o.datatype = 'ip4addr'
        o.placeholder = "114.114.114.114"

        o = s.taboption('dns', form.Value, 'secure_dns', _('Secure DNS'), _("DNS for resolving geosite:geolocation-!cn sites"))
        o.datatype = 'ip4addr'
        o.placeholder = "1.1.1.1"

        o = s.taboption('dns', form.Value, 'default_dns', _('Default DNS'), _("DNS for resolving other sites"))
        o.datatype = 'ip4addr'
        o.placeholder = "8.8.8.8"

        s.tab('access_control', _('Transparent Proxy Rules'));

        o = s.taboption('access_control', form.DynamicList, "wan_bp_ips", _("Bypassed IP"), _("Won't redirect for these IPs. Make sure that your remote proxy server IP added here."))
        o.datatype = "ip4addr"
        o.rmempty = false

        o = s.taboption('access_control', form.DynamicList, "wan_fw_ips", _("Forwarded IP"))
        o.datatype = "ip4addr"
        o.rmempty = true

        s = m.section(form.GridSection, 'servers', _('Xray Servers'))

        s.sortable = true
        s.anonymous = true
        s.addremove = true

        s.tab('general', _('General Settings'));

        o = s.taboption('general', form.Value, "alias", _("Alias (optional)"))
        o.rmempty = true

        o = s.taboption('general', form.Value, 'server', _('Server Hostname'))
        o.datatype = 'host'

        o = s.taboption('general', form.Value, 'server_port', _('Server Port'))
        o.datatype = 'port'
        o.placeholder = '443'

        o = s.taboption('general', form.Value, 'password', _('UserId / Password'), _('Fill user_id for vmess / VLESS, or password for shadowsocks / trojan'))
        o.modalonly = true

        s.tab('protocol', _('Protocol Settings'));

        o = s.taboption('protocol', form.ListValue, "protocol", _("Protocol"))
        o.value("vmess", "VMess")
        o.value("vless", "VLESS")
        o.value("trojan", "Trojan")
        o.value("shadowsocks", "Shadowsocks")
        o.rmempty = false

        o = s.taboption('protocol', form.ListValue, "shadowsocks_security", _("[shadowsocks] Encrypt Method"))
        o.depends("protocol", "shadowsocks")
        o.value("none", "none")
        o.value("aes-256-gcm", "aes-256-gcm")
        o.value("aes-128-gcm", "aes-128-gcm")
        o.value("chacha20-poly1305", "chacha20-poly1305")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption('protocol', form.ListValue, "shadowsocks_tls", _("[shadowsocks] Stream Security"))
        o.depends("protocol", "shadowsocks")
        o.value("none", "None")
        o.value("tls", "TLS")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption('protocol', form.Value, "shadowsocks_tls_host", _("[shadowsocks][tls] Server Name"))
        o.depends("shadowsocks_tls", "tls")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('protocol', form.Flag, "shadowsocks_tls_insecure", _("[shadowsocks][tls] Allow Insecure"))
        o.depends("shadowsocks_tls", "tls")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption('protocol', form.ListValue, "trojan_tls", _("[trojan] Stream Security"))
        o.depends("protocol", "trojan")
        o.value("none", "None")
        o.value("tls", "TLS")
        o.value("xtls", "XTLS")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption('protocol', form.Value, "trojan_tls_host", _("[trojan][tls] Server Name"))
        o.depends("trojan_tls", "tls")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('protocol', form.Flag, "trojan_tls_insecure", _("[trojan][tls] Allow Insecure"))
        o.depends("trojan_tls", "tls")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption('protocol', form.Value, "trojan_xtls_host", _("[trojan][xtls] Server Name"))
        o.depends("trojan_tls", "xtls")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('protocol', form.Flag, "trojan_xtls_insecure", _("[trojan][xtls] Allow Insecure"))
        o.depends("trojan_tls", "xtls")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption('protocol', form.ListValue, "trojan_flow", _("[trojan] Flow"))
        o.depends("protocol", "trojan")
        o.value("none", "none")
        o.value("xtls-rprx-origin", "xtls-rprx-origin")
        o.value("xtls-rprx-direct", "xtls-rprx-direct")
        o.value("xtls-rprx-splice", "xtls-rprx-splice")
        o.value("xtls-rprx-origin-udp443", "xtls-rprx-origin-udp443")
        o.value("xtls-rprx-direct-udp443", "xtls-rprx-direct-udp443")
        o.value("xtls-rprx-splice-udp443", "xtls-rprx-splice-udp443")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption('protocol', form.ListValue, "vmess_security", _("[vmess] Encrypt Method"))
        o.depends("protocol", "vmess")
        o.value("none", "none")
        o.value("auto", "auto")
        o.value("aes-128-gcm", "aes-128-gcm")
        o.value("chacha20-poly1305", "chacha20-poly1305")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption('protocol', form.ListValue, "vmess_alter_id", _("[vmess] AlterId"))
        o.depends("protocol", "vmess")
        o.value(0, "0 (this enables VMessAEAD)")
        o.value(1, "1")
        o.value(4, "4")
        o.value(16, "16")
        o.value(64, "64")
        o.value(256, "256")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption('protocol', form.ListValue, "vmess_tls", _("[vmess] Stream Security"))
        o.depends("protocol", "vmess")
        o.value("none", "None")
        o.value("tls", "TLS")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption('protocol', form.Value, "vmess_tls_host", _("[vmess][tls] Server Name"))
        o.depends("vmess_tls", "tls")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('protocol', form.Flag, "vmess_tls_insecure", _("[vmess][tls] Allow Insecure"))
        o.depends("vmess_tls", "tls")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption('protocol', form.ListValue, "vless_encryption", _("[vless] Encrypt Method"))
        o.depends("protocol", "vless")
        o.value("none", "none")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption('protocol', form.ListValue, "vless_flow", _("[vless] Flow"))
        o.depends("protocol", "vless")
        o.value("none", "none")
        o.value("xtls-rprx-origin", "xtls-rprx-origin")
        o.value("xtls-rprx-direct", "xtls-rprx-direct")
        o.value("xtls-rprx-splice", "xtls-rprx-splice")
        o.value("xtls-rprx-origin-udp443", "xtls-rprx-origin-udp443")
        o.value("xtls-rprx-direct-udp443", "xtls-rprx-direct-udp443")
        o.value("xtls-rprx-splice-udp443", "xtls-rprx-splice-udp443")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption('protocol', form.ListValue, "vless_tls", _("[vless] Stream Security"))
        o.depends("protocol", "vless")
        o.value("none", "None")
        o.value("tls", "TLS")
        o.value("xtls", "XTLS")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption('protocol', form.Value, "vless_tls_host", _("[vless][tls] Server Name"))
        o.depends("vless_tls", "tls")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('protocol', form.Flag, "vless_tls_insecure", _("[vless][tls] Allow Insecure"))
        o.depends("vless_tls", "tls")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption('protocol', form.Value, "vless_xtls_host", _("[vless][xtls] Server Name"))
        o.depends("vless_tls", "xtls")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('protocol', form.Flag, "vless_xtls_insecure", _("[vless][xtls] Allow Insecure"))
        o.depends("vless_tls", "xtls")
        o.rmempty = false
        o.modalonly = true

        s.tab('transport', _('Transport Settings'));

        o = s.taboption('transport', form.ListValue, 'transport', _('Transport'))
        o.value("tcp", "TCP")
        o.value("mkcp", "mKCP")
        o.value("ws", "WebSocket")
        o.value("h2", "HTTP/2")
        o.value("quic", "QUIC")
        o.rmempty = false

        o = s.taboption('transport', form.ListValue, "tcp_guise", _("[tcp] Fake Header Type"))
        o.depends("transport", "tcp")
        o.value("none", _("None"))
        o.value("http", "HTTP")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.DynamicList, "http_host", _("[tcp][fake_http] Host"))
        o.depends("tcp_guise", "http")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.DynamicList, "http_path", _("[tcp][fake_http] Path"))
        o.depends("tcp_guise", "http")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.ListValue, "mkcp_guise", _("[mkcp] Fake Header Type"))
        o.depends("transport", "mkcp")
        o.value("none", _("None"))
        o.value("srtp", _("VideoCall (SRTP)"))
        o.value("utp", _("BitTorrent (uTP)"))
        o.value("wechat-video", _("WechatVideo"))
        o.value("dtls", "DTLS 1.2")
        o.value("wireguard", "WireGuard")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.Value, "mkcp_mtu", _("[mkcp] Maximum Transmission Unit"))
        o.datatype = "uinteger"
        o.depends("transport", "mkcp")
        o.default = 1350
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.Value, "mkcp_tti", _("[mkcp] Transmission Time Interval"))
        o.datatype = "uinteger"
        o.depends("transport", "mkcp")
        o.default = 50
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.Value, "mkcp_uplink_capacity", _("[mkcp] Uplink Capacity"))
        o.datatype = "uinteger"
        o.depends("transport", "mkcp")
        o.default = 5
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.Value, "mkcp_downlink_capacity", _("[mkcp] Downlink Capacity"))
        o.datatype = "uinteger"
        o.depends("transport", "mkcp")
        o.default = 20
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.Value, "mkcp_read_buffer_size", _("[mkcp] Read Buffer Size"))
        o.datatype = "uinteger"
        o.depends("transport", "mkcp")
        o.default = 2
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.Value, "mkcp_write_buffer_size", _("[mkcp] Write Buffer Size"))
        o.datatype = "uinteger"
        o.depends("transport", "mkcp")
        o.default = 2
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.Flag, "mkcp_congestion", _("[mkcp] Congestion Control"))
        o.depends("transport", "mkcp")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.Value, "mkcp_seed", _("[mkcp] Seed"))
        o.depends("transport", "mkcp")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.ListValue, "quic_security", _("[quic] Security"))
        o.depends("transport", "quic")
        o.value("none", "none")
        o.value("aes-128-gcm", "aes-128-gcm")
        o.value("chacha20-poly1305", "chacha20-poly1305")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption('transport', form.Value, "quic_key", _("[quic] Key"))
        o.depends("transport", "quic")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.ListValue, "quic_guise", _("[quic] Fake Header Type"))
        o.depends("transport", "quic")
        o.value("none", _("None"))
        o.value("srtp", _("VideoCall (SRTP)"))
        o.value("utp", _("BitTorrent (uTP)"))
        o.value("wechat-video", _("WechatVideo"))
        o.value("dtls", "DTLS 1.2")
        o.value("wireguard", "WireGuard")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.DynamicList, "h2_host", _("[http2] Host"))
        o.depends("transport", "h2")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.Value, "h2_path", _("[http2] Path"))
        o.depends("transport", "h2")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.Value, "ws_host", _("[websocket] Host"))
        o.depends("transport", "ws")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.Value, "ws_path", _("[websocket] Path"))
        o.depends("transport", "ws")
        o.rmempty = true
        o.modalonly = true

        return m.render();
    }
});
