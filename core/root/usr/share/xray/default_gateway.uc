#!/usr/bin/ucode
"use strict";

import { open, popen, stat } from "fs";
import { connect } from "ubus";

function network_dump() {
    const ubus = connect();
    if (ubus) {
        const result = ubus.call("network.interface", "dump");
        ubus.disconnect();
        return result;
    }
    return {
        "interface": []
    };
}

function get_default_gateway(dump) {
    let dgs = {};
    for (let i in dump["interface"] || []) {
        for (let j in i["route"] || []) {
            if (j["target"] == "0.0.0.0") {
                dgs[j["nexthop"]] = true;
                if (j["source"] != "0.0.0.0/0") {
                    dgs[j["source"]] = true;
                }
            }
        }
    };
    return keys(dgs);
}

function get_prefix_delegate(dump) {
    let pds = {};
    for (let i in dump["interface"] || []) {
        for (let j in i["ipv6-prefix"] || []) {
            if (j["assigned"]) {
                pds[`${j["address"]}/${j["mask"]}`] = true;
            }
        }
    }
    return keys(pds);
}

function gen_tp_spec_dv4_dg(dg) {
    if (stat("/usr/share/xray/ignore_tp_spec_def_gw")) {
        return "";
    }
    if (length(dg) > 0) {
        return `set tp_spec_dv4_dg {
            type ipv4_addr
            size 16
            flags interval
            elements = { ${join(", ", dg)} }
        }\n`;
    }
    return "";
}

function gen_tp_spec_dv6_dg(pd) {
    if (length(pd) > 0) {
        return `set tp_spec_dv6_dg {
            type ipv6_addr
            size 16
            flags interval
            elements = { ${join(", ", pd)} }
        }\n`;
    }
    return "";
}

function generate_include(dg, pd) {
    const handle = open("/var/etc/xray/gateway_include.nft", "w");
    handle.write(gen_tp_spec_dv4_dg(dg));
    handle.write(gen_tp_spec_dv6_dg(pd));
    handle.flush();
    handle.close();
}

function update_nft(dg, pd) {
    const handle = popen("nft -f -", "w");
    handle.write(`table inet fw4 {
        ${gen_tp_spec_dv4_dg(dg)}
        ${gen_tp_spec_dv6_dg(pd)}
    }`);
    handle.flush();
    handle.close();
}

function restart_dnsmasq_if_necessary() {
    if (stat("/usr/share/xray/restart_dnsmasq_on_iface_change")) {
        system("service dnsmasq restart");
    }
}

const dump = network_dump();
const dg = get_default_gateway(dump);
const pd = get_prefix_delegate(dump);
const log = join(", ", [...dg, ...pd]);
if (log == "") {
    print("default gateway not available, please wait for interface ready");
} else {
    print(`default gateway available at ${log}\n`);
    update_nft(dg, pd);
    generate_include(dg, pd);
}
restart_dnsmasq_if_necessary();
