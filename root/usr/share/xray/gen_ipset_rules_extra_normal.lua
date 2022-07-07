#!/usr/bin/lua

local special_purpose_rules = [[add tp_spec_dst_sp 255.255.255.255
add tp_spec_dst_sp 0.0.0.0/8
add tp_spec_dst_sp 10.0.0.0/8
add tp_spec_dst_sp 100.64.0.0/10
add tp_spec_dst_sp 127.0.0.0/8
add tp_spec_dst_sp 169.254.0.0/16
add tp_spec_dst_sp 172.16.0.0/12
add tp_spec_dst_sp 192.0.0.0/24
add tp_spec_dst_sp 192.0.2.0/24
add tp_spec_dst_sp 192.88.99.0/24
add tp_spec_dst_sp 192.168.0.0/16
add tp_spec_dst_sp 198.18.0.0/15
add tp_spec_dst_sp 198.51.100.0/24
add tp_spec_dst_sp 203.0.113.0/24
add tp_spec_dst_sp 224.0.0.0/4
add tp_spec_dst_sp 233.252.0.0/24
add tp_spec_dst_sp 240.0.0.0/4]]

return function(proxy)
    print(special_purpose_rules)
end
