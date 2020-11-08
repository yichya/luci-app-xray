#!/usr/bin/lua
local ucursor = require "luci.model.uci"
local json = require "luci.jsonc"

local proxy_section = ucursor:get_first("v2fly", "general")
local proxy = ucursor:get_all("v2fly", proxy_section)

local server_section = proxy.main_server
local server = ucursor:get_all("v2fly", server_section)

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

local function stream_tcp_fake_http_request()
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

local function stream_tcp_fake_http_response()
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

local function stream_tcp()
    if server.transport == "tcp" then
        return {
            header = {
                type = server.tcp_guise,
                request = stream_tcp_fake_http_request(),
                response = stream_tcp_fake_http_response()
            }
        }
    else
        return nil
    end
end

local function stream_h2()
    if (server.transport == "h2") then 
        return {
            path = server.h2_path,
            host = server.h2_host
        } 
    else 
        return nil
    end  
end

local function stream_ws()
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

local function stream_kcp()
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

local function stream_quic()
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

local function shadowsocks_outbound()
    return {
        protocol = "shadowsocks",
        tag = "outbound",
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
            tlsSettings = server.shadowsocks_tls == "tls" and {
                serverName = server.shadowsocks_tls_host,
                allowInsecure = server.shadowsocks_tls_insecure ~= "0"
            } or nil,
            quicSettings = stream_quic(),
            tcpSettings = stream_tcp(),
            kcpSettings = stream_kcp(),
            wsSettings = stream_ws(),
            httpSettings = stream_h2()
        }
    }
end

local function vmess_outbound()
    return {
        protocol = "vmess",
        tag = "outbound",
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
            tlsSettings = server.vmess_tls == "tls" and {
                serverName = server.vmess_tls_host,
                allowInsecure = server.vmess_tls_insecure ~= "0"
            } or nil,
            quicSettings = stream_quic(),
            tcpSettings = stream_tcp(),
            kcpSettings = stream_kcp(),
            wsSettings = stream_ws(),
            httpSettings = stream_h2()
        }
    }
end

local function vless_outbound()
    return {
        protocol = "vless",
        tag = "outbound",
        settings = {
            vnext = {
                {
                    address = server.server,
                    port = tonumber(server.server_port),
                    users = {
                        {
                            id = server.password,
                            flow = server.vless_flow,
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
            tlsSettings = server.vless_tls == "tls" and {
                serverName = server.vless_tls_host,
                allowInsecure = server.vless_tls_insecure ~= "0"
            } or nil,
            xtlsSettings = server.vless_tls == "xtls" and {
                serverName = server.vless_xtls_host,
                allowInsecure = server.vless_xtls_insecure ~= "0"
            } or nil,
            quicSettings = stream_quic(),
            tcpSettings = stream_tcp(),
            kcpSettings = stream_kcp(),
            wsSettings = stream_ws(),
            httpSettings = stream_h2()
        }
    }
end

local function trojan_outbound()
    return {
        protocol = "trojan",
        tag = "outbound",
        settings = {
            servers = {
                {
                    address = server.server,
                    port = tonumber(server.server_port),
                    password = server.password,
                }
            }
        },
        streamSettings = {
            network = server.transport,
            sockopt = {
                mark = tonumber(proxy.mark)
            },
            security = server.trojan_tls,
            tlsSettings = server.trojan_tls == "tls" and {
                serverName = server.trojan_tls_host,
                allowInsecure = server.trojan_tls_insecure ~= "0"
            } or nil,
            xtlsSettings = server.trojan_tls == "xtls" and {
                serverName = server.trojan_xtls_host,
                allowInsecure = server.trojan_xtls_insecure ~= "0"
            } or nil,
            quicSettings = stream_quic(),
            tcpSettings = stream_tcp(),
            kcpSettings = stream_kcp(),
            wsSettings = stream_ws(),
            httpSettings = stream_h2()
        }
    }
end

local function server_outbound() 
    if server.protocol == "vmess" then
        return vmess_outbound()
    end
    if server.protocol == "vless" then 
        return vless_outbound()
    end
    if server.protocol == "shadowsocks" then
        return shadowsocks_outbound()
    end
    if server.protocol == "trojan" then
        return trojan_outbound()
    end
    return {}
end

local function tproxy_inbound()
    return {
        port = proxy.tproxy_port,
        protocol = "dokodemo-door",
        tag = "tproxy_inbound",
        settings = {
            network = "tcp,udp",
            followRedirect = true
        },
        streamSettings = {
            sockopt = {
                tproxy = "tproxy"
            }
        }
    }
end

local function dns_server_inbound()
    return {
        port = proxy.dns_port,
        protocol = "dokodemo-door",
        tag = "dns_server_inbound",
        settings = {
            address = "208.67.220.220",
            port = 443,
            network = "tcp,udp"
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

local function dns_server_outbound()
    return {
        protocol = "dns",
        tag = "dns_server_outbound"
    }
end

local function dns_conf()
    return {
        servers = {
            {
                address = proxy.secure_dns,
                port = 53,
                domains = {"geosite:geolocation-!cn"}
            },
            {
                address = proxy.fast_dns,
                port = 53,
                domains = {"geosite:cn"}
            },
            proxy.default_dns
        },
        tag = "dns_conf_inbound"
    }
end

local v2ray = {
    inbounds = {
        http_inbound(),
        tproxy_inbound(),
        socks_inbound(),
        dns_server_inbound()
    },
    outbounds = {
        server_outbound(),
        direct_outbound(),
        dns_server_outbound()
    },
    dns = dns_conf(),
    routing = {
        domainStrategy = "AsIs",
        rules = {
            {
                type = "field",
                inboundTag = {"tproxy_inbound", "dns_conf_inbound"},
                outboundTag = "direct",
                ip = {"geoip:cn"}
            },
            {
                type = "field",
                inboundTag = {"tproxy_inbound", "socks_inbound", "dns_conf_inbound"},
                outboundTag = "direct",
                ip = {"geoip:private"}
            },
            {
                type = "field",
                inboundTag = {"socks_inbound", "tproxy_inbound", "dns_conf_inbound"},
                outboundTag = "outbound"
            },
            {
                type = "field",
                inboundTag = {"dns_server_inbound"},
                outboundTag = "dns_server_outbound"
            }
        }
    }
}

print(json.stringify(v2ray, true))
