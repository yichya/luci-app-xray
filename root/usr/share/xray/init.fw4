FIREWALL_INCLUDE="/usr/share/xray/firewall_include.ut"

setup_firewall() {
    ip route add local default dev lo table 100
    ip rule  add fwmark 0x2333        table 100

    logger -st xray[$$] -p4 "Generating firewall4 rules..."
    /usr/bin/utpl ${FIREWALL_INCLUDE} > /var/etc/xray/firewall_include.nft

    logger -st xray[$$] -p4 "Triggering firewall4 restart..."
    /etc/init.d/firewall restart > /dev/null 2>&1
}

flush_firewall() {
    ip rule  del   table 100
    ip route flush table 100

    logger -st xray[$$] -p4 "Flushing firewall4 rules..."
    rm /var/etc/xray/firewall_include.nft

    logger -st xray[$$] -p4 "Triggering firewall4 restart..."
    /etc/init.d/firewall restart > /dev/null 2>&1
}

impl_gen_config_file() {
    /usr/bin/ucode /usr/share/xray/gen_config.uc > /var/etc/xray/config.json
}
