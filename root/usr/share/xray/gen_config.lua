#!/usr/bin/lua
local ucursor = require "luci.model.uci"
local json = require "luci.jsonc"
local nixiofs = require "nixio.fs"

local proxy_section = ucursor:get_first("xray", "general")
local proxy = ucursor:get_all("xray", proxy_section)

local tcp_server_section = proxy.main_server
local tcp_server = ucursor:get_all("xray", tcp_server_section)

local udp_server_section = proxy.tproxy_udp_server
local udp_server = ucursor:get_all("xray", udp_server_section)

local geoip_existence = false
local geosite_existence = false

local xray_data_file_iterator = nixiofs.dir("/usr/share/xray")

repeat 
    local fn = xray_data_file_iterator()
    if fn == "geoip.dat" then
        geoip_existence = true
    end
    if fn == "geosite.dat" then
        geosite_existence = true
    end
until fn == nil

local function direct_outbound()
    return {
        protocol = "freedom",
        tag = "direct",
        settings = {keep = ""},
        streamSettings = {
            sockopt = {
                mark = tonumber(proxy.mark)
            }
        }
    }
end

local function stream_tcp_fake_http_request(server)
    if server.tcp_guise == "http" then
        return {
            version = "1.1",
            method = "GET",
            path = server.http_path,
            headers = {
                Host = server.http_host,
                User_Agent = {
                    "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.75 Safari/537.36",
                    "Mozilla/5.0 (iPhone; CPU iPhone OS 10_0_2 like Mac OS X) AppleWebKit/601.1 (KHTML, like Gecko) CriOS/53.0.2785.109 Mobile/14A456 Safari/601.1.46"
                },
                Accept_Encoding = {"gzip, deflate"},
                Connection = {"keep-alive"},
                Pragma = "no-cache"
            }
        }
    else
        return nil
    end
end

local function stream_tcp_fake_http_response(server)
    if server.tcp_guise == "http" then
        return {
            version = "1.1",
            status = "200",
            reason = "OK",
            headers = {
                Content_Type = {"application/octet-stream", "video/mpeg"},
                Transfer_Encoding = {"chunked"},
                Connection = {"keep-alive"},
                Pragma = "no-cache"
            }
        }
    else
        return nil
    end
end

local function stream_tcp(server)
    if server.transport == "tcp" then
        return {
            header = {
                type = server.tcp_guise,
                request = stream_tcp_fake_http_request(server),
                response = stream_tcp_fake_http_response(server)
            }
        }
    else
        return nil
    end
end

local function stream_h2(server)
    if (server.transport == "h2") then
        return {
            path = server.h2_path,
            host = server.h2_host
        }
    else
        return nil
    end
end

local function stream_ws(server)
    if server.transport == "ws" then
        local headers = nil
        if (server.ws_host ~= nil) then
            headers = {
                Host = server.ws_host
            }
        end
        return {
            path = server.ws_path,
            headers = headers
        }
    else
        return nil
    end
end

local function stream_kcp(server)
    if server.transport == "mkcp" then
        local mkcp_seed = nil
        if server.mkcp_seed ~= "" then
            mkcp_seed = server.mkcp_seed
        end
        return {
            mtu = tonumber(server.mkcp_mtu),
            tti = tonumber(server.mkcp_tti),
            uplinkCapacity = tonumber(server.mkcp_uplink_capacity),
            downlinkCapacity = tonumber(server.mkcp_downlink_capacity),
            congestion = server.mkcp_congestion == "1",
            readBufferSize = tonumber(server.mkcp_read_buffer_size),
            writeBufferSize = tonumber(server.mkcp_write_buffer_size),
            seed = mkcp_seed,
            header = {
                type = server.mkcp_guise
            }
        }
    else
        return nil
    end
end

local function stream_quic(server)
    if server.transport == "quic" then
        return {
            security = server.quic_security,
            key = server.quic_key,
            header = {
                type = server.quic_guise
            }
        }
    else
        return nil
    end
end

local function tls_settings(server, protocol)
    return {
        serverName = server[protocol .. "_tls_host"],
        allowInsecure = server[protocol .. "_tls_insecure"] ~= "0",
        fingerprint = server[protocol .. "_tls_fingerprint"] or "",
    }
end

local function xtls_settings(server, protocol)
    return {
        serverName = server[protocol .. "_xtls_host"],
        allowInsecure = server[protocol .. "_xtls_insecure"] ~= "0",
    }
end

local function shadowsocks_outbound(server, tag)
    return {
        protocol = "shadowsocks",
        tag = tag,
        settings = {
            servers = {
                {
                    address = server.server,
                    port = tonumber(server.server_port),
                    password = server.password,
                    method = server.shadowsocks_security
                }
            }
        },
        streamSettings = {
            network = server.transport,
            sockopt = {
                mark = tonumber(proxy.mark)
            },
            security = server.shadowsocks_tls,
            tlsSettings = server.shadowsocks_tls == "tls" and tls_settings(server, "shadowsocks") or nil,
            quicSettings = stream_quic(server),
            tcpSettings = stream_tcp(server),
            kcpSettings = stream_kcp(server),
            wsSettings = stream_ws(server),
            httpSettings = stream_h2(server)
        }
    }
end

local function vmess_outbound(server, tag)
    return {
        protocol = "vmess",
        tag = tag,
        settings = {
            vnext = {
                {
                    address = server.server,
                    port = tonumber(server.server_port),
                    users = {
                        {
                            id = server.password,
                            alterId = tonumber(server.alter_id),
                            security = server.vmess_security
                        }
                    }
                }
            }
        },
        streamSettings = {
            network = server.transport,
            sockopt = {
                mark = tonumber(proxy.mark)
            },
            security = server.vmess_tls,
            tlsSettings = server.vmess_tls == "tls" and tls_settings(server, "vmess") or nil,
            quicSettings = stream_quic(server),
            tcpSettings = stream_tcp(server),
            kcpSettings = stream_kcp(server),
            wsSettings = stream_ws(server),
            httpSettings = stream_h2(server)
        }
    }
end

local function vless_outbound(server, tag)
    local flow = server.vless_flow
    if server.vless_flow == "none" then
        flow = nil
    end
    return {
        protocol = "vless",
        tag = tag,
        settings = {
            vnext = {
                {
                    address = server.server,
                    port = tonumber(server.server_port),
                    users = {
                        {
                            id = server.password,
                            flow = flow,
                            encryption = server.vless_encryption
                        }
                    }
                }
            }
        },
        streamSettings = {
            network = server.transport,
            sockopt = {
                mark = tonumber(proxy.mark)
            },
            security = server.vless_tls,
            tlsSettings = server.vless_tls == "tls" and tls_settings(server, "vless") or nil,
            xtlsSettings = server.vless_tls == "xtls" and xtls_settings(server, "vless") or nil,
            quicSettings = stream_quic(server),
            tcpSettings = stream_tcp(server),
            kcpSettings = stream_kcp(server),
            wsSettings = stream_ws(server),
            httpSettings = stream_h2(server)
        }
    }
end

local function trojan_outbound(server, tag)
    local flow = server.trojan_flow
    if server.trojan_flow == "none" then
        flow = nil
    end
    return {
        protocol = "trojan",
        tag = tag,
        settings = {
            servers = {
                {
                    address = server.server,
                    port = tonumber(server.server_port),
                    password = server.password,
                    flow = flow,
                }
            }
        },
        streamSettings = {
            network = server.transport,
            sockopt = {
                mark = tonumber(proxy.mark)
            },
            security = server.trojan_tls,
            tlsSettings = server.trojan_tls == "tls" and tls_settings(server, "trojan") or nil,
            xtlsSettings = server.trojan_tls == "xtls" and xtls_settings(server, "trojan") or nil,
            quicSettings = stream_quic(server),
            tcpSettings = stream_tcp(server),
            kcpSettings = stream_kcp(server),
            wsSettings = stream_ws(server),
            httpSettings = stream_h2(server)
        }
    }
end

local function server_outbound(server, tag)
    if server.protocol == "vmess" then
        return vmess_outbound(server, tag)
    end
    if server.protocol == "vless" then
        return vless_outbound(server, tag)
    end
    if server.protocol == "shadowsocks" then
        return shadowsocks_outbound(server, tag)
    end
    if server.protocol == "trojan" then
        return trojan_outbound(server, tag)
    end
    error("unknown outbound server protocol")
end

local function tproxy_tcp_inbound()
    return {
        port = proxy.tproxy_port_tcp,
        protocol = "dokodemo-door",
        tag = "tproxy_tcp_inbound",
        settings = {
            network = "tcp",
            followRedirect = true
        },
        streamSettings = {
            sockopt = {
                tproxy = "tproxy",
                mark = tonumber(proxy.mark)
            }
        }
    }
end

local function tproxy_udp_inbound()
    return {
        port = proxy.tproxy_port_udp,
        protocol = "dokodemo-door",
        tag = "tproxy_udp_inbound",
        settings = {
            network = "udp",
            followRedirect = true
        },
        streamSettings = {
            sockopt = {
                tproxy = "tproxy",
                mark = tonumber(proxy.mark)
            }
        }
    }
end

local function http_inbound()
    return {
        port = proxy.http_port,
        protocol = "http",
        tag = "http_inbound",
        settings = {
            allowTransparent = false
        }
    }
end

local function socks_inbound()
    return {
        port = proxy.socks_port,
        protocol = "socks",
        tag = "socks_inbound",
        settings = {
            udp = true
        }
    }
end

local function fallbacks()
    local f = {}
    ucursor:foreach("xray", "fallback", function(s)
        if s.dest ~= nil then
            table.insert(f, {
                dest = s.dest,
                alpn = s.alpn,
                name = s.name,
                xver = s.xver,
                path = s.path
            })
        end
    end)
    table.insert(f, {
        dest = proxy.web_server_address
    })
    return f
end

local function https_trojan_inbound()
    return {
        port = 443,
        protocol = "trojan",
        tag = "https_inbound",
        settings = {
            clients = {
                {
                    id = proxy.web_server_password
                }
            },
            fallbacks = fallbacks()
        },
        streamSettings = {
            network = "tcp",
            security = proxy.trojan_tls,
            tlsSettings = proxy.trojan_tls == "tls" and {
                alpn = {
                    "http/1.1"
                },
                certificates = {
                    {
                        certificateFile = proxy.web_server_cert_file,
                        keyFile = proxy.web_server_key_file
                    }
                }
            } or nil,
            xtlsSettings = proxy.trojan_tls == "xtls" and {
                alpn = {
                    "http/1.1"
                },
                certificates = {
                    {
                        certificateFile = proxy.web_server_cert_file,
                        keyFile = proxy.web_server_key_file
                    }
                }
            } or nil
        }
    }
end

local function https_vless_inbound()
    return {
        port = 443,
        protocol = "vless",
        tag = "https_inbound",
        settings = {
            clients = {
                {
                    id = proxy.web_server_password,
                }
            },
            decryption = "none",
            fallbacks = fallbacks()
        },
        streamSettings = {
            network = "tcp",
            security = proxy.vless_tls,
            tlsSettings = proxy.vless_tls == "tls" and {
                alpn = {
                    "http/1.1"
                },
                certificates = {
                    {
                        certificateFile = proxy.web_server_cert_file,
                        keyFile = proxy.web_server_key_file
                    }
                }
            } or nil,
            xtlsSettings = proxy.vless_tls == "xtls" and {
                alpn = {
                    "http/1.1"
                },
                certificates = {
                    {
                        certificateFile = proxy.web_server_cert_file,
                        keyFile = proxy.web_server_key_file
                    }
                }
            } or nil
        }
    }
end

local function https_inbound()
    if proxy.web_server_protocol == "vless" then
        return https_vless_inbound()
    end
    if proxy.web_server_protocol == "trojan" then
        return https_trojan_inbound()
    end
    return nil
end

local function dns_server_inbound()
    return {
        port = proxy.dns_port,
        protocol = "dokodemo-door",
        tag = "dns_server_inbound",
        settings = {
            address = proxy.default_dns,
            port = 53,
            network = "tcp,udp"
        }
    }
end

local function dns_server_outbound()
    return {
        protocol = "dns",
        tag = "dns_server_outbound"
    }
end

local function dns_conf()
    local fast_domain_rules = {
        tcp_server.server,
        udp_server.server
    }
    if proxy.bypassed_domain_rules ~= nil then
        for _, x in ipairs(proxy.bypassed_domain_rules) do
            table.insert(fast_domain_rules, x)
        end
    end

    local servers = {
        {
            address = proxy.fast_dns,
            port = 53,
            domains = fast_domain_rules,
        },
        proxy.default_dns
    }

    if proxy.forwarded_domain_rules ~= nil then
        local secure_domain_rules = {}
        for _, x in ipairs(proxy.forwarded_domain_rules) do
            table.insert(secure_domain_rules, x)
        end
        table.insert(servers, 2, {
            address = proxy.secure_dns,
            port = 53,
            domains = secure_domain_rules,
        })
    end

    return {
        servers = servers,
        tag = "dns_conf_inbound"
    }
end

local function api_conf()
    if proxy.xray_api == '1' then
        return {
            tag = "api",
            services = {
                "HandlerService",
                "LoggerService",
                "StatsService"
            }
        }
    else
        return nil
    end
end

local function inbounds()
    local i = {
        http_inbound(),
        tproxy_tcp_inbound(),
        tproxy_udp_inbound(),
        socks_inbound(),
        dns_server_inbound()
    }
    if proxy.web_server_enable == "1" then
        table.insert(i, https_inbound())
    end
    if proxy.xray_api == '1' then
        table.insert(i, {
            listen = "127.0.0.1",
            port = 8080,
            protocol = "dokodemo-door",
            settings = {
                address = "127.0.0.1"
            },
            tag = "api"
        })
    end
    return i
end

local function rules()
    rules = {
        {
            type = "field",
            inboundTag = {"tproxy_tcp_inbound", "tproxy_udp_inbound", "socks_inbound", "https_inbound", "http_inbound", "dns_conf_inbound"},
            outboundTag = "direct",
            ip = {"geoip:private"}
        },
        {
            type = "field",
            inboundTag = {"socks_inbound", "https_inbound", "http_inbound", "tproxy_tcp_inbound", "dns_conf_inbound"},
            outboundTag = "tcp_outbound"
        },
        {
            type = "field",
            inboundTag = {"tproxy_udp_inbound"},
            outboundTag = "udp_outbound"
        },
        {
            type = "field",
            inboundTag = {"dns_server_inbound"},
            outboundTag = "dns_server_outbound"
        },
        {
            type = "field",
            inboundTag = {"api"},
            outboundTag = "api"
        }
    }
    if geoip_existence then 
        if proxy.geoip_direct_code ~= nil then
            table.insert(rules, 1, {
                type = "field",
                inboundTag = {"tproxy_tcp_inbound", "tproxy_udp_inbound", "dns_conf_inbound"},
                outboundTag = "direct",
                ip = {"geoip:" .. proxy.geoip_direct_code}
            })
        end
    end
    return rules
end

local xray = {
    inbounds = inbounds(),
    outbounds = {
        server_outbound(tcp_server, "tcp_outbound"),
        server_outbound(udp_server, "udp_outbound"),
        direct_outbound(),
        dns_server_outbound()
    },
    dns = dns_conf(),
    api = api_conf(),
    routing = {
        domainStrategy = "AsIs",
        rules = rules()
    }
}

print(json.stringify(xray, true))
