#!/usr/bin/lua
local ucursor = require "luci.model.uci"

local flush = [[# firewall include file to stop transparent proxy
ip rule  del   table 100
ip route flush table 100
iptables-save -c | grep -v "XRAY" | iptables-restore -c]]
local header = [[# firewall include file to start transparent proxy
ip route add local default dev lo table 100
ip rule  add fwmark 0x2333        table 100

iptables-restore -n <<-EOF
*mangle
:XRAY_RULES - [0:0]
:XRAY_PROXY - [0:0]
]]
local rules = [[
##### XRAY_RULES #####
# ignore traffic marked by xray outbound
-A XRAY_RULES -m mark --mark 0x%x -j RETURN
# connection-mark -> packet-mark
-A XRAY_RULES -j CONNMARK --restore-mark
# ignore established connections
-A XRAY_RULES -m mark --mark 0x2333 -j RETURN

# ignore traffic sent to reserved addresses
-A XRAY_RULES -m set --match-set tp_spec_dst_sp dst -j RETURN

# route traffic depends on whitelist/blacklists
-A XRAY_RULES -m set --match-set tp_spec_src_bp src -j RETURN
-A XRAY_RULES -m set --match-set tp_spec_src_fw src -j XRAY_PROXY

-A XRAY_RULES -m set --match-set tp_spec_dst_fw dst -j XRAY_PROXY
-A XRAY_RULES -m set --match-set tp_spec_dst_bp dst -j RETURN
-A XRAY_RULES -j XRAY_PROXY

##### XRAY_PROXY #####
# mark the first packet of the connection
-A XRAY_PROXY -p tcp --syn                      -j MARK --set-mark 0x2333
-A XRAY_PROXY -p udp -m conntrack --ctstate NEW -j MARK --set-mark 0x2333

# packet-mark -> connection-mark
-A XRAY_PROXY -j CONNMARK --save-mark

##### OUTPUT #####
-A OUTPUT -p tcp -m addrtype --src-type LOCAL ! --dst-type LOCAL -j XRAY_RULES
-A OUTPUT -p udp -m addrtype --src-type LOCAL ! --dst-type LOCAL -j XRAY_RULES

##### PREROUTING #####
# proxy traffic passing through this machine (other->other)
-A PREROUTING -i %s -p tcp -m addrtype ! --src-type LOCAL ! --dst-type LOCAL -j XRAY_RULES
-A PREROUTING -i %s -p udp -m addrtype ! --src-type LOCAL ! --dst-type LOCAL -j XRAY_RULES

# hand over the marked package to TPROXY for processing
-A PREROUTING -p tcp -m mark --mark 0x2333 -j TPROXY --on-ip 127.0.0.1 --on-port %d
-A PREROUTING -p udp -m mark --mark 0x2333 -j TPROXY --on-ip 127.0.0.1 --on-port %d

COMMIT
EOF]]

local proxy_section = ucursor:get_first("xray", "general")
local proxy = ucursor:get_all("xray", proxy_section)

print(flush)
if proxy.transparent_proxy_enable ~= "1" then
    do
        return
    end
end
if arg[1] == "enable" then
    print(header)
    print(string.format(rules, tonumber(proxy.mark),
        proxy.lan_ifaces, proxy.lan_ifaces,
        proxy.tproxy_port_tcp, proxy.tproxy_port_udp))
else
    print("# arg[1] == " .. arg[1] .. ", not enable")
end
