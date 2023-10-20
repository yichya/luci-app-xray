#!/usr/bin/ucode
"use strict";

import { popen, stat } from "fs";
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
                dgs[j["source"]] = true;
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

function get_lan_addresses(dump) {
    let l4s = {};
    let l6s = {};
    for (let i in dump["interface"] || []) {
        if (i["l3_device"] == "br-lan") {
            for (let j in i["ipv4-address"] || []) {
                l4s[j["address"]] = true;
            }
            for (let k in i["ipv6-prefix-assignment"] || []) {
                let la = k["local-address"];
                if (la != null) {
                    l6s[la["address"]] = true;
                }
            }
        }
    }
    return { l4s: keys(l4s), l6s: keys(l6s) };
}

function gen_tp_spec_dv4_dg(dg) {
    if (stat("/usr/share/xray/ignore_tp_spec_def_gw")) {
        return "";
    }
    if (length(dg) > 0) {
        return `flush set inet fw4 tp_spec_dv4_dg\nadd element inet fw4 tp_spec_dv4_dg { ${join(", ", dg)} }\n`;
    }
    return "";
}

function gen_tp_spec_dv6_dg(pd) {
    if (length(pd) > 0) {
        return `flush set inet fw4 tp_spec_dv6_dg\nadd element inet fw4 tp_spec_dv6_dg { ${join(", ", pd)} }\n`;
    }
    return "";
}

function gen_tp_spec_lv4_dr(l4s) {
    if (length(l4s) > 0) {
        return `flush set inet fw4 tp_spec_lv4_dr\nadd element inet fw4 tp_spec_lv4_dr { ${join(", ", l4s)} }\n`;
    }
    return "";
}

function gen_tp_spec_lv6_dr(l6s) {
    if (length(l6s) > 0) {
        return `flush set inet fw4 tp_spec_lv6_dr\nadd element inet fw4 tp_spec_lv6_dr { ${join(", ", l6s)} }\n`;
    }
    return "";
}

function update_nft(dg, pd, lans) {
    const process = popen("nft -f -", "w");
    process.write(gen_tp_spec_dv4_dg(dg));
    process.write(gen_tp_spec_dv6_dg(pd));
    process.write(gen_tp_spec_lv4_dr(lans.l4s));
    process.write(gen_tp_spec_lv6_dr(lans.l6s));
    process.flush();
    process.close();
}

function restart_dnsmasq_if_necessary() {
    if (stat("/usr/share/xray/restart_dnsmasq_on_iface_change")) {
        system("service dnsmasq restart");
    }
}

const dump = network_dump();
const dg = get_default_gateway(dump);
const pd = get_prefix_delegate(dump);
const lans = get_lan_addresses(dump);
const log = join(", ", [...dg, ...pd, ...lans.l4s, ...lans.l6s]);
if (log == "") {
    print("default gateway not available, please wait for interface ready");
} else {
    print(`default gateway available at ${log}\n`);
    update_nft(dg, pd, lans);
}
restart_dnsmasq_if_necessary();
