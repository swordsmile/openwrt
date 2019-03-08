#!/bin/sh

# System
uci set system.@system[0].hostname='OpenWrt'
uci set system.@system[0].timezone='CST-8'

# Network
uci set network.lan.ipaddr='192.168.8.1'
uci set network.wan.proto='dhcp'

uci commit

# Soft
cp /etc/opkg/distfeeds.conf ~/
sed -i "s#http://downloads.openwrt.org#https://mirrors.tuna.tsinghua.edu.cn/lede#g" /etc/opkg/distfeeds.conf

opkg update

# opkg install vim-full vim-runtime

# 智能翻墙 ipset 篇
# HTTPS
opkg install ca-certificates ca-bundle
opkg install ip-full wget
opkg install iptables-mod-nat-extra iptables-mod-tproxy ipset iptables-mod-geoip
opkg remove dnsmasq && opkg install dnsmasq-full
opkg install tinc wireguard shadowsocks-libev unbound ipset

if [ -d uci get dhcp.@dnsmasq[0].confdir ]; then
	mkdir -p /etc/dnsmasq.d
	uci add_list dhcp.@dnsmasq[0].confdir=/etc/dnsmasq.d
	uci commit dhcp
fi

# IPList for China by IPIP.NET
wget -O /etc/gfw/china_ip_list.txt https://github.com/17mon/china_ip_list/raw/master/china_ip_list.txt
# ipset 5353 gfwlist
wget -O /etc/dnsmasq.d/dnsmasq_gfwlist_ipset.conf https://cokebar.github.io/gfwlist2dnsmasq/dnsmasq_gfwlist_ipset.conf

# 加速 DNS 缓存 /etc/dnsmasq.conf
cache-size=10000
min-cache-ttl=1800

# 
wget -O /etc/dnsmasq.d/accelerated-domains.china https://github.com/felixonmars/dnsmasq-china-list/raw/master/accelerated-domains.china.conf
sed -i "s/114.114.114.114/119.29.29.29/g" /etc/dnsmasq.d/accelerated-domains.china


# usb
opkg install kmod-usb2 block-mount samba36-server

# Dropbear 证书登陆



