'use strict';
'require view';
'require uci';
'require form';

function add_flow_and_stream_security_conf(s, tab_name, depends_field_name, protocol_name, have_xtls, client_side) {
    var o;

    o = s.taboption(tab_name, form.ListValue, `${protocol_name}_tls`, _(`[${protocol_name}] Stream Security`))
    let odep = {}
    odep[depends_field_name] = protocol_name
    if (client_side) {
        o.depends(depends_field_name, protocol_name)
        o.value("none", "None")
    } else {
        odep["web_server_enable"] = "1"
    }
    o.value("tls", "TLS")
    if (have_xtls) {
        o.value("xtls", "XTLS")
    }
    o.depends(odep)
    o.rmempty = false
    o.modalonly = true

    if (have_xtls) {
        o = s.taboption(tab_name, form.ListValue, `${protocol_name}_flow`, _(`[${protocol_name}][xtls] Flow`))
        let odep = {}
        odep[depends_field_name] = protocol_name
        odep[`${protocol_name}_tls`] = "xtls"
        o.value("none", "none")
        o.value("xtls-rprx-origin", "xtls-rprx-origin")
        o.value("xtls-rprx-origin-udp443", "xtls-rprx-origin-udp443")
        o.value("xtls-rprx-direct", "xtls-rprx-direct")
        o.value("xtls-rprx-direct-udp443", "xtls-rprx-direct-udp443")
        if (client_side) {
            o.value("xtls-rprx-splice", "xtls-rprx-splice")
            o.value("xtls-rprx-splice-udp443", "xtls-rprx-splice-udp443")
        } else {
            odep["web_server_enable"] = "1"
        }
        o.depends(odep)
        o.rmempty = false
        o.modalonly = true
    }

    if (client_side) {
        o = s.taboption(tab_name, form.Value, `${protocol_name}_tls_host`, _(`[${protocol_name}][tls] Server Name`))
        o.depends(`${protocol_name}_tls`, "tls")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption(tab_name, form.Flag, `${protocol_name}_tls_insecure`, _(`[${protocol_name}][tls] Allow Insecure`))
        o.depends(`${protocol_name}_tls`, "tls")
        o.rmempty = false
        o.modalonly = true

        o = s.taboption(tab_name, form.ListValue, `${protocol_name}_tls_fingerprint`, _(`[${protocol_name}][tls] Fingerprint`))
        o.depends(`${protocol_name}_tls`, "tls")
        o.value("", "(not set)")
        o.value("chrome", "chrome")
        o.value("firefox", "firefox")
        o.value("safari", "safari")
        o.value("randomized", "randomized")
        o.rmempty = true
        o.modalonly = true

        if (have_xtls) {
            o = s.taboption(tab_name, form.Value, `${protocol_name}_xtls_host`, _(`[${protocol_name}][xtls] Server Name`))
            o.depends(`${protocol_name}_tls`, "xtls")
            o.rmempty = true
            o.modalonly = true

            o = s.taboption(tab_name, form.Flag, `${protocol_name}_xtls_insecure`, _(`[${protocol_name}][xtls] Allow Insecure`))
            o.depends(`${protocol_name}_tls`, "xtls")
            o.rmempty = false
            o.modalonly = true
        }
    }
}

function check_resource_files(load_result) {
    let geoip_existence = false;
    let geosite_existence = false;
    for (const f of load_result) {
        if (f.name == "geoip.dat") {
            geoip_existence = true
        }
        if (f.name == "geosite.dat") {
            geosite_existence = true
        }
    }
    return {
        geoip_existence: geoip_existence,
        geosite_existence: geosite_existence
    }
}

return view.extend({
    load: function () {
        return Promise.all([
            L.uci.load("xray"),
            L.uci.fs.list("/usr/share/xray")
        ])
    },

    render: function (load_result) {
        const config_data = load_result[0];
        const { geoip_existence, geosite_existence } = check_resource_files(load_result[1]);

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

        o = s.taboption('general', form.Flag, 'xray_api', _('Enable Xray API Service'))

        o = s.taboption('general', form.Flag, 'transparent_proxy_enable', _('Enable Transparent Proxy'))

        o = s.taboption('general', form.ListValue, 'tproxy_udp_server', _('TProxy UDP Server'))
        o.depends("transparent_proxy_enable", "1")
        for (var v of L.uci.sections(config_data, "servers")) {
            o.value(v[".name"], v.alias || v.server + ":" + v.server_port)
        }

        s.tab('proxy', _('Proxy Settings'));

        o = s.taboption('proxy', form.Value, 'tproxy_port_tcp', _('Transparent Proxy Port (TCP)'))
        o.datatype = 'port'
        o.default = 1080

        o = s.taboption('proxy', form.Value, 'tproxy_port_udp', _('Transparent Proxy Port (UDP)'))
        o.datatype = 'port'
        o.default = 1080

        o = s.taboption('proxy', form.Value, 'socks_port', _('Socks5 Proxy Port'))
        o.datatype = 'port'
        o.default = 1082

        o = s.taboption('proxy', form.Value, 'http_port', _('HTTP Proxy Port'))
        o.datatype = 'port'
        o.default = 1083

        o = s.taboption('proxy', form.Value, 'dns_port', _('Xray DNS Server Port'))
        o.datatype = 'port'
        o.default = 5353

        o = s.taboption('proxy', form.Value, 'mark', _('Socket Mark Number'), _('Avoid proxy loopback problems with local (gateway) traffic'))
        o.datatype = 'range(1, 255)'
        o.default = 255

        s.tab('dns', _('DNS Settings'));

        o = s.taboption('dns', form.Value, 'fast_dns', _('Fast DNS'), _("DNS for resolving outbound domains and following bypassed domains"))
        o.datatype = 'ip4addr'
        o.placeholder = "114.114.114.114"

        if (geosite_existence) {
            o = s.taboption('dns', form.DynamicList, "bypassed_domain_rules", _('Bypassed domain rules'), _("Specify rules like 'geosite:cn' or 'domain:bilibili.com'. See <a href=\"https://xtls.github.io/config/base/dns/\">documentation</a> for details."))
        } else {
            o = s.taboption('dns', form.DynamicList, 'bypassed_domain_rules', _('Bypassed domain rules'), _("Specify rules like 'domain:bilibili.com' or see <a href=\"https://xtls.github.io/config/base/dns/\">documentation</a> for details.<br/> In order to use Geosite rules you need a valid resource file /usr/share/xray/geosite.dat.<br/>Compile your firmware again with data files to use Geosite rules, or <a href=\"https://github.com/v2fly/domain-list-community\">download one</a> and upload it to your router."))
        }
        o.rmempty = true

        o = s.taboption('dns', form.Value, 'secure_dns', _('Secure DNS'), _("DNS for resolving known polluted domains (specify forwarded domain rules here)"))
        o.datatype = 'ip4addr'
        o.placeholder = "114.114.114.114"

        if (geosite_existence) {
            o = s.taboption('dns', form.DynamicList, "forwarded_domain_rules", _('Forwarded domain rules'), _("Specify rules like 'geosite:geolocation-!cn' or 'domain:youtube.com'. See <a href=\"https://xtls.github.io/config/base/dns/\">documentation</a> for details."))
        } else {
            o = s.taboption('dns', form.DynamicList, 'forwarded_domain_rules', _('Forwarded domain rules'), _("Specify rules like 'domain:youtube.com' or see <a href=\"https://xtls.github.io/config/base/dns/\">documentation</a> for details.<br/> In order to use Geosite rules you need a valid resource file /usr/share/xray/geosite.dat.<br/>Compile your firmware again with data files to use Geosite rules, or <a href=\"https://github.com/v2fly/domain-list-community\">download one</a> and upload it to your router."))
        }
        o.rmempty = true

        o = s.taboption('dns', form.Value, 'default_dns', _('Default DNS'), _("DNS for resolving other sites (and Dokodemo outbound)"))
        o.datatype = 'ip4addr'
        o.placeholder = "8.8.8.8"

        s.tab('access_control', _('Transparent Proxy Rules'));

        if (geoip_existence) {
            o = s.taboption('access_control', form.Value, 'geoip_direct_code', _('GeoIP Direct Code'), _("Hosts in this GeoIP set will not be forwarded through Xray. Set to unspecified to forward all non-private hosts."))
        } else {
            o = s.taboption('access_control', form.Value, 'geoip_direct_code', _('GeoIP Direct Code'), _("Resource file /usr/share/xray/geoip.dat not exist. All network traffic will be forwarded. <br/> Compile your firmware again with data files to use this feature, or<br/><a href=\"https://github.com/v2fly/geoip\">download one</a> (maybe disable transparent proxy first) and upload it to your router."))
            o.readonly = true
        }
        o.value("cn", "cn")
        o.value("telegram", "telegram")
        o.datatype = "string"

        o = s.taboption('access_control', form.DynamicList, "wan_bp_ips", _("Bypassed IP"), _("Won't redirect for these IPs. Make sure that your remote proxy server IP added here."))
        o.datatype = "ip4addr"
        o.rmempty = false

        o = s.taboption('access_control', form.DynamicList, "wan_fw_ips", _("Forwarded IP"))
        o.datatype = "ip4addr"
        o.rmempty = true

        s.tab('xray_server', _('HTTPS Server'));

        o = s.taboption('xray_server', form.Flag, 'web_server_enable', _('Enable Xray HTTPS Server'), _("This will start a HTTPS server at port 443 which serves both as an inbound for Xray and a reverse proxy web server"));
        o = s.taboption('xray_server', form.FileUpload, 'web_server_cert_file', _('Certificate File'));
        o.root_directory = "/etc/luci-uploads/xray"
        o.depends("web_server_enable", "1")

        o = s.taboption('xray_server', form.FileUpload, 'web_server_key_file', _('Private Key File'));
        o.root_directory = "/etc/luci-uploads/xray"
        o.depends("web_server_enable", "1")

        o = s.taboption('xray_server', form.ListValue, "web_server_protocol", _("Protocol"), _("Only protocols which support fallback are available"));
        o.value("vless", "VLESS")
        o.value("trojan", "Trojan")
        o.rmempty = false
        o.depends("web_server_enable", "1")

        add_flow_and_stream_security_conf(s, "xray_server", "web_server_protocol", "vless", true, false)

        add_flow_and_stream_security_conf(s, "xray_server", "web_server_protocol", "trojan", true, false)

        o = s.taboption('xray_server', form.Value, 'web_server_password', _('UserId / Password'), _('Fill user_id for vmess / VLESS, or password for shadowsocks / trojan (also supports Xray UUID Mapping)'))
        o.depends("web_server_enable", "1")

        o = s.taboption('xray_server', form.Value, 'web_server_address', _('Default Fallback HTTP Server'), _('Support for multiple fallbacks (path, SNI) is under development'))
        o.datatype = 'hostport'
        o.depends("web_server_enable", "1")

        s.tab('custom_options', _('Custom Options'))
        o = s.taboption('custom_options', form.TextValue, 'custom_config', _('Custom Configurations'))
        o.monospace = true
        o.rows = 10

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

        o = s.taboption('general', form.Value, 'password', _('UserId / Password'), _('Fill user_id for vmess / VLESS, or password for shadowsocks / trojan (also supports Xray UUID Mapping)'))
        o.modalonly = true

        s.tab('protocol', _('Protocol Settings'));

        o = s.taboption('protocol', form.ListValue, "protocol", _("Protocol"))
        o.value("vmess", "VMess")
        o.value("vless", "VLESS")
        o.value("trojan", "Trojan")
        o.value("shadowsocks", "Shadowsocks")
        o.rmempty = false

        add_flow_and_stream_security_conf(s, "protocol", "protocol", "trojan", true, true)

        o = s.taboption('protocol', form.ListValue, "shadowsocks_security", _("[shadowsocks] Encrypt Method"))
        o.depends("protocol", "shadowsocks")
        o.value("none", "none")
        o.value("aes-256-gcm", "aes-256-gcm")
        o.value("aes-128-gcm", "aes-128-gcm")
        o.value("chacha20-poly1305", "chacha20-poly1305")
        o.rmempty = false
        o.modalonly = true

        add_flow_and_stream_security_conf(s, "protocol", "protocol", "shadowsocks", false, true)

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

        add_flow_and_stream_security_conf(s, "protocol", "protocol", "vmess", false, true)

        o = s.taboption('protocol', form.ListValue, "vless_encryption", _("[vless] Encrypt Method"))
        o.depends("protocol", "vless")
        o.value("none", "none")
        o.rmempty = false
        o.modalonly = true

        add_flow_and_stream_security_conf(s, "protocol", "protocol", "vless", true, true)

        s.tab('transport', _('Transport Settings'));

        o = s.taboption('transport', form.ListValue, 'transport', _('Transport'))
        o.value("tcp", "TCP")
        o.value("mkcp", "mKCP")
        o.value("ws", "WebSocket")
        o.value("h2", "HTTP/2")
        o.value("quic", "QUIC")
        o.value("grpc", "gRPC")
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

        o = s.taboption('transport', form.Value, "grpc_service_name", _("[grpc] Service Name"))
        o.depends("transport", "grpc")
        o.rmempty = true
        o.modalonly = true

        o = s.taboption('transport', form.Flag, "grpc_multi_mode", _("[grpc] Multi Mode"))
        o.depends("transport", "grpc")
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

        s = m.section(form.GridSection, 'fallback', _('Xray Fallback'))

        s.sortable = true
        s.anonymous = true
        s.addremove = true

        s.tab('general', _('General Settings'));

        o = s.taboption('general', form.Value, "name", _("SNI"))
        o.rmempty = true

        o = s.taboption('general', form.Value, "alpn", _("ALPN"))
        o.rmempty = true

        o = s.taboption('general', form.Value, "path", _("Path"))
        o.rmempty = true

        o = s.taboption('general', form.Value, "xver", _("Xver"))
        o.datatype = "uinteger"
        o.rmempty = true

        o = s.taboption('general', form.Value, "dest", _("Destination Address"))
        o.datatype = 'hostport'
        o.rmempty = true

        return m.render();
    }
});
