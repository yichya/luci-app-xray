#!/usr/bin/ucode
"use strict";

import { lsdir } from "fs";
import { load_config } from "./common/config.mjs";
import { balancer, api_conf, metrics_conf, logging, policy, system_route_rules } from "./feature/system.mjs";
import { blocked_domain_rules, fast_domain_rules, secure_domain_rules, dns_server_tags, dns_server_inbounds, dns_server_outbound, dns_conf } from "./feature/dns.mjs";
import { socks_inbound, http_inbound, https_inbound, dokodemo_inbound } from "./feature/inbound.mjs";
import { blackhole_outbound, direct_outbound, server_outbound } from "./feature/outbound.mjs";
import { bridges, bridge_outbounds, bridge_rules } from "./feature/bridge.mjs";
import { extra_inbounds, extra_inbound_rules, extra_inbound_global_tcp_tags, extra_inbound_global_udp_tags, extra_inbound_balancers } from "./feature/extra_inbound.mjs";
import { manual_tproxy_outbounds, manual_tproxy_outbound_tags, manual_tproxy_rules } from "./feature/manual_tproxy.mjs";
import { fake_dns_balancers, fake_dns_conf, fake_dns_rules } from "./feature/fake_dns.mjs";

function inbounds(proxy, config, extra_inbound) {
    let i = [
        socks_inbound("0.0.0.0", proxy["socks_port"] || 1080, "socks_inbound"),
        http_inbound("0.0.0.0", proxy["http_port"] || 1081, "http_inbound"),
        dokodemo_inbound("0.0.0.0", proxy["tproxy_port_tcp_v4"] || 1082, "tproxy_tcp_inbound_v4", proxy["tproxy_sniffing"], proxy["route_only"], ["http", "tls"], "0", "tcp", "tproxy", proxy["conn_idle"]),
        dokodemo_inbound("0.0.0.0", proxy["tproxy_port_tcp_v6"] || 1083, "tproxy_tcp_inbound_v6", proxy["tproxy_sniffing"], proxy["route_only"], ["http", "tls"], "0", "tcp", "tproxy", proxy["conn_idle"]),
        dokodemo_inbound("0.0.0.0", proxy["tproxy_port_udp_v4"] || 1084, "tproxy_udp_inbound_v4", proxy["tproxy_sniffing"], proxy["route_only"], ["quic"], "0", "udp", "tproxy", proxy["conn_idle"]),
        dokodemo_inbound("0.0.0.0", proxy["tproxy_port_udp_v6"] || 1085, "tproxy_udp_inbound_v6", proxy["tproxy_sniffing"], proxy["route_only"], ["quic"], "0", "udp", "tproxy", proxy["conn_idle"]),
        ...extra_inbounds(proxy, extra_inbound),
        ...dns_server_inbounds(proxy),
        dokodemo_inbound("0.0.0.0", proxy["tproxy_port_tcp_f4"] || 1086, "tproxy_tcp_inbound_f4", "1", "0", ["fakedns"], "1", "tcp", "tproxy", proxy["fake_dns_timeout"]),
        dokodemo_inbound("0.0.0.0", proxy["tproxy_port_tcp_f6"] || 1087, "tproxy_tcp_inbound_f6", "1", "0", ["fakedns"], "1", "tcp", "tproxy", proxy["fake_dns_timeout"]),
        dokodemo_inbound("0.0.0.0", proxy["tproxy_port_udp_f4"] || 1088, "tproxy_udp_inbound_f4", "1", "0", ["fakedns"], "1", "udp", "tproxy", proxy["fake_dns_timeout"]),
        dokodemo_inbound("0.0.0.0", proxy["tproxy_port_udp_f6"] || 1089, "tproxy_udp_inbound_f6", "1", "0", ["fakedns"], "1", "udp", "tproxy", proxy["fake_dns_timeout"]),
    ];
    if (proxy["web_server_enable"] == "1") {
        push(i, https_inbound(proxy, config));
    }
    if (proxy["metrics_server_enable"] == '1') {
        push(i, {
            listen: "0.0.0.0",
            port: int(proxy["metrics_server_port"]) || 18888,
            protocol: "dokodemo-door",
            settings: {
                address: "127.0.0.1"
            },
            tag: "metrics"
        });
    }
    if (proxy["xray_api"] == '1') {
        push(i, {
            listen: "127.0.0.1",
            port: 8080,
            protocol: "dokodemo-door",
            settings: {
                address: "127.0.0.1"
            },
            tag: "api"
        });
    }
    return i;
}

function outbounds(proxy, config, manual_tproxy, bridge, extra_inbound, fakedns) {
    let result = [
        direct_outbound("direct"),
        blackhole_outbound(),
        dns_server_outbound(),
        ...manual_tproxy_outbounds(config, manual_tproxy),
        ...bridge_outbounds(config, bridge)
    ];
    let outbound_balancers_all = {};
    for (let b in ["tcp_balancer_v4", "udp_balancer_v4", "tcp_balancer_v6", "udp_balancer_v6"]) {
        for (let i in balancer(proxy, b, b)) {
            if (i != "direct") {
                outbound_balancers_all[i] = true;
            }
        }
    }
    for (let e in extra_inbound) {
        if (e["specify_outbound"] == "1") {
            for (let i in balancer(e, "destination", `extra_inbound:${e[".name"]}`)) {
                if (i != "direct") {
                    outbound_balancers_all[i] = true;
                }
            }
        }
    }
    for (let f in fakedns) {
        for (let i in balancer(f, "fake_dns_forward_server_tcp", `fake_dns_tcp:${f[".name"]}`)) {
            if (i != "direct") {
                outbound_balancers_all[i] = true;
            }
        }
        for (let i in balancer(f, "fake_dns_forward_server_udp", `fake_dns_udp:${f[".name"]}`)) {
            if (i != "direct") {
                outbound_balancers_all[i] = true;
            }
        }
    }
    for (let i in keys(outbound_balancers_all)) {
        push(result, ...server_outbound(config[substr(i, -9)], i, config));
    }
    return result;
}

function rules(geoip_existence, proxy, bridge, manual_tproxy, extra_inbound, fakedns) {
    const tproxy_tcp_inbound_v4_tags = ["tproxy_tcp_inbound_v4"];
    const tproxy_udp_inbound_v4_tags = ["tproxy_udp_inbound_v4"];
    const tproxy_tcp_inbound_v6_tags = ["tproxy_tcp_inbound_v6"];
    const tproxy_udp_inbound_v6_tags = ["tproxy_udp_inbound_v6"];
    const built_in_tcp_inbounds = [...tproxy_tcp_inbound_v4_tags, "socks_inbound", "https_inbound", "http_inbound"];
    const built_in_udp_inbounds = [...tproxy_udp_inbound_v4_tags, "dns_conf_inbound"];
    const extra_inbound_global_tcp = extra_inbound_global_tcp_tags() || [];
    const extra_inbound_global_udp = extra_inbound_global_udp_tags() || [];
    let result = [
        ...fake_dns_rules(fakedns),
        ...manual_tproxy_rules(manual_tproxy),
        ...extra_inbound_rules(extra_inbound),
        ...system_route_rules(proxy),
        ...bridge_rules(bridge),
        ...function () {
            let direct_rules = [];
            if (geoip_existence) {
                if (proxy["geoip_direct_code_list"] != null) {
                    const geoip_direct_code_list = map(proxy["geoip_direct_code_list"] || [], v => "geoip:" + v);
                    if (length(geoip_direct_code_list) > 0) {
                        push(direct_rules, {
                            type: "field",
                            inboundTag: [...built_in_tcp_inbounds, ...built_in_udp_inbounds, ...extra_inbound_global_tcp, ...extra_inbound_global_udp],
                            outboundTag: "direct",
                            ip: geoip_direct_code_list
                        });
                    }
                    const geoip_direct_code_list_v6 = map(proxy["geoip_direct_code_list_v6"] || [], v => "geoip:" + v);
                    if (length(geoip_direct_code_list_v6) > 0) {
                        push(direct_rules, {
                            type: "field",
                            inboundTag: [...tproxy_tcp_inbound_v6_tags, ...tproxy_udp_inbound_v6_tags],
                            outboundTag: "direct",
                            ip: geoip_direct_code_list_v6
                        });
                    }
                }
                push(direct_rules, {
                    type: "field",
                    inboundTag: [...tproxy_tcp_inbound_v6_tags, ...tproxy_udp_inbound_v6_tags, ...built_in_tcp_inbounds, ...built_in_udp_inbounds, ...extra_inbound_global_tcp, ...extra_inbound_global_udp],
                    outboundTag: "direct",
                    ip: ["geoip:private"]
                });
            }
            return direct_rules;
        }(),
        {
            type: "field",
            inboundTag: [...tproxy_tcp_inbound_v6_tags],
            balancerTag: "tcp_outbound_v6"
        },
        {
            type: "field",
            inboundTag: [...tproxy_udp_inbound_v6_tags],
            balancerTag: "udp_outbound_v6"
        },
        {
            type: "field",
            inboundTag: [...built_in_tcp_inbounds, ...extra_inbound_global_tcp],
            balancerTag: "tcp_outbound_v4"
        },
        {
            type: "field",
            inboundTag: [...built_in_udp_inbounds, ...extra_inbound_global_udp],
            balancerTag: "udp_outbound_v4"
        },
        {
            type: "field",
            inboundTag: dns_server_tags(proxy),
            outboundTag: "dns_server_outbound"
        },
    ];
    if (proxy["tproxy_sniffing"] == "1") {
        if (length(secure_domain_rules(proxy)) > 0) {
            splice(result, 0, 0, {
                type: "field",
                inboundTag: [...tproxy_tcp_inbound_tags, ...extra_inbound_global_tcp],
                balancerTag: "tcp_outbound_v4",
                domain: secure_domain_rules(proxy),
            }, {
                type: "field",
                inboundTag: [...tproxy_udp_inbound_tags, ...extra_inbound_global_udp],
                balancerTag: "udp_outbound_v4",
                domain: secure_domain_rules(proxy),
            });
        }
        if (length(blocked_domain_rules(proxy)) > 0) {
            splice(result, 0, 0, {
                type: "field",
                inboundTag: [...tproxy_tcp_inbound_tags, ...tproxy_tcp_inbound_tags, ...extra_inbound_global_tcp, ...extra_inbound_global_udp],
                outboundTag: "blackhole_outbound",
                domain: blocked_domain_rules(proxy),
            });
        }
        splice(result, 0, 0, {
            type: "field",
            inboundTag: [...tproxy_tcp_inbound_tags, ...tproxy_tcp_inbound_tags, ...extra_inbound_global_tcp, ...extra_inbound_global_udp],
            outboundTag: "direct",
            domain: fast_domain_rules(proxy)
        });
        if (proxy["direct_bittorrent"] == "1") {
            splice(result, 0, 0, {
                type: "field",
                outboundTag: "direct",
                protocol: ["bittorrent"]
            });
        }
    }
    return result;
}

function balancers(proxy, extra_inbound, fakedns, balancer_strategy) {
    let result = [
        {
            "tag": "tcp_outbound_v4",
            "selector": balancer(proxy, "tcp_balancer_v4", "tcp_balancer_v4"),
            "strategy": {
                "type": balancer_strategy
            }
        },
        {
            "tag": "udp_outbound_v4",
            "selector": balancer(proxy, "udp_balancer_v4", "udp_balancer_v4"),
            "strategy": {
                "type": balancer_strategy
            }
        },
        {
            "tag": "tcp_outbound_v6",
            "selector": balancer(proxy, "tcp_balancer_v6", "tcp_balancer_v6"),
            "strategy": {
                "type": balancer_strategy
            }
        },
        {
            "tag": "udp_outbound_v6",
            "selector": balancer(proxy, "udp_balancer_v6", "udp_balancer_v6"),
            "strategy": {
                "type": balancer_strategy
            }
        },
        ...extra_inbound_balancers(extra_inbound, balancer_strategy),
        ...fake_dns_balancers(fakedns, balancer_strategy),
    ];

    return result;
};

function observatory(proxy, manual_tproxy) {
    if (proxy["observatory"] == "1") {
        return {
            subjectSelector: ["tcp_balancer_v4@balancer_outbound", "udp_balancer_v4@balancer_outbound", "tcp_balancer_v6@balancer_outbound", "udp_balancer_v6@balancer_outbound", "extra_inbound", "fake_dns", "direct", ...manual_tproxy_outbound_tags(manual_tproxy)],
            probeInterval: "100ms",
            probeUrl: "http://www.apple.com/library/test/success.html"
        };
    }
    return null;
}

function gen_config() {
    const balancer_strategy = "random";

    const share_dir = lsdir("/usr/share/xray");
    const geoip_existence = index(share_dir, "geoip.dat") > 0;

    const config = load_config();
    const general = config[filter(keys(config), k => config[k][".type"] == "general")[0]];
    const bridge = map(filter(keys(config), k => config[k][".type"] == "bridge") || [], k => config[k]);
    const fakedns = map(filter(keys(config), k => config[k][".type"] == "fakedns") || [], k => config[k]);
    const extra_inbound = map(filter(keys(config), k => config[k][".type"] == "extra_inbound") || [], k => config[k]);
    const manual_tproxy = map(filter(keys(config), k => config[k][".type"] == "manual_tproxy") || [], k => config[k]);

    return {
        inbounds: inbounds(general, config, extra_inbound),
        outbounds: outbounds(general, config, manual_tproxy, bridge, extra_inbound, fakedns),
        dns: dns_conf(general, config, manual_tproxy, fakedns),
        fakedns: fake_dns_conf(general),
        api: api_conf(general),
        metrics: metrics_conf(general),
        policy: policy(general),
        log: logging(general),
        stats: general["stats"] == "1" ? {
            place: "holder"
        } : null,
        observatory: observatory(general, manual_tproxy),
        reverse: {
            bridges: bridges(bridge)
        },
        routing: {
            domainStrategy: general["routing_domain_strategy"] || "AsIs",
            rules: rules(geoip_existence, general, bridge, manual_tproxy, extra_inbound, fakedns),
            balancers: balancers(general, extra_inbound, fakedns, balancer_strategy)
        }
    };
}

print(gen_config());
