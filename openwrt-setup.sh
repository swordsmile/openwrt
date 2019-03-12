#!/bin/sh

opkg update

# System
uci set system.@system[0].hostname='OpenWrt'
uci set system.@system[0].timezone='CST-8'

# Network
uci set network.lan.ipaddr='192.168.8.1'
uci set network.wan.proto='dhcp'

# Wireless
uci set wireless.radio0.channel='6'
uci set wireless.radio0.disabled='0'
uci set wireless.default_radio0.ssid='OpenWrt-Gl-iNet'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='GoodWifi$'


uci commit

/etc/init.d/network restart

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
opkg install tinc wireguard unbound ipset
opkg install shadowsocks-libev-config shadowsocks-libev-ss-local shadowsocks-libev-ss-redir

# shadowsocks-libev
uci set shadowsocks-libev.hi.disabled='0'
uci set shadowsocks-libev.hi.server='sss0'
uci set shadowsocks-libev.hi.local_address='127.0.0.1'
uci set shadowsocks-libev.hi.local_port='1090'
# uci set shadowsocks-libev.hi.plugin='/usr/bin/obfs-local'
# uci set shadowsocks-libev.hi.plugin_opts='obfs=tls;obfs-host=www.bing.com;fast-open'

uci set shadowsocks-libev.sss0.disabled='0'
uci set shadowsocks-libev.sss0.server='122.9.51.100'
uci set shadowsocks-libev.sss0.server_port='8443'
uci set shadowsocks-libev.sss0.password='shadow.hk1'
uci set shadowsocks-libev.sss0.method='xchacha20-ietf-poly1305'

# uci set shadowsocks-libev.sss0.plugin='/usr/bin/obfs-local'
# uci set shadowsocks-libev.sss0.plugin_opts='obfs=tls;obfs-host=www.bing.com;fast-open'

uci commit shadowsocks-libev



if [ -d uci get dhcp.@dnsmasq[0].confdir ]; then
	mkdir -p /etc/dnsmasq.d
	uci add_list dhcp.@dnsmasq[0].confdir=/etc/dnsmasq.d
	uci commit dhcp
fi

cat <<EOF
{
        "fast_open": true,
        "local_address": "0.0.0.0",
        "local_port": 1090,
        "mode": "tcp_and_udp",
        "timeout": 60,
        "server": "127.0.0.1",
        "server_port": 8443,
        "method": "xchacha20-ietf-poly1305",
        "password": "password"
}
EOF

# IPList for China by IPIP.NET
wget -O /etc/gfw/china_ip_list.txt https://github.com/17mon/china_ip_list/raw/master/china_ip_list.txt
# ipset 5353 gfwlist
wget -O /etc/dnsmasq.d/dnsmasq_gfwlist_ipset.conf https://cokebar.github.io/gfwlist2dnsmasq/dnsmasq_gfwlist_ipset.conf

# 加速 DNS 缓存 /etc/dnsmasq.conf
cache-size=10000
min-cache-ttl=1800

# unbound
opkg install bind-dig

uci set unbound.@unbound[0].manual_conf='1'
uci commit unbound

sed -i "s/# port: 53/port: 5353/g" unbound.conf
sed -n "/port: 53/p" unbound.conf
sed -i "s/# cache-min-ttl: 0/cache-min-ttl: 43200/g" unbound.conf

/etc/init.d/unbound enable
/etc/init.d/unbound start

# Adding DNS-Over-TLS support to OpenWRT (LEDE) with Unbound
https://blog.cloudflare.com/dns-over-tls-for-openwrt/
/etc/unbound/unbound.conf
forward-addr: 8.8.8.8@853
forward-ssl-upstream: yes

# 
wget -O /etc/dnsmasq.d/accelerated-domains.china https://github.com/felixonmars/dnsmasq-china-list/raw/master/accelerated-domains.china.conf
sed -i "s/114.114.114.114/119.29.29.29/g" /etc/dnsmasq.d/accelerated-domains.china


# usb
opkg install kmod-usb2 block-mount samba36-server

# Dropbear 证书登陆
# 在有证书的电脑上
ssh-copy-id root@192.168.x.1 -p 22
# 在路由器上
cp /root/.ssh/authorized_keys /etc/dropbear/

# kernel
cat << EOF > /etc/sysctl.d/23-swordsmile.conf
net.ipv4.tcp_fastopen = 3
fs.file-max = 16384
EOF
/etc/init.d/sysctl restart


# udp2raw
## server
[Unit]
Description=udp2raw Service
After=network.target
Wants=network.target

[Service]
User=nobody
Group=nobody
Type=simple
PIDFile=/run/udp2raw.pid
ExecStart=/usr/local/bin/udp2raw_amd64_hw_aes --conf-file /etc/udp2raw/udp2raw_server.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target

-s
-l 0.0.0.0:2443
-r 127.0.0.1:1443
-k password
--raw-mode faketcp

setcap cap_net_raw+ep /usr/local/bin/udp2raw_amd64_hw_aes
iptables -I INPUT -p tcp -m tcp --dport 2443 -j DROP

# tinc
sed -i "s/NETNAME/openwrt/g" /etc/config/tinc
sed -i "s/NODENAME/glinet/g" /etc/config/tinc
sed -i "s/option enabled 0/option enabled 1/g" /etc/config/tinc
sed -i "s/#list ConnectTo peer1/list ConnectTo hkvps/g" /etc/config/tinc
sed -i "s/#option Interface openwrt/option Interface tinc/g" /etc/config/tinc
sed -i "s/#option PrivateKeyFile/option PrivateKeyFile/g" /etc/config/tinc
sed -i "s/#option Subnet 192.168.1.0\/24/option Subnet 10.88.0.8\/32/g" /etc/config/tinc

mkdir -pv /etc/tinc/openwrt/hosts

cat << EOF > /etc/tinc/openwrt/tinc-up
#!/bin/sh
ubus -t 15 wait_for network.interface.\$INTERFACE
ip link set \$INTERFACE up
ip addr add 10.88.0.8/32 dev \$INTERFACE
ip route add 10.88.0.0/24 dev \$INTERFACE
EOF

cat << EOF > /etc/tinc/openwrt/tinc-down
#!/bin/sh
ip route del 10.88.0.0/24 dev \$INTERFACE
ip addr del 10.88.0.8/32 dev \$INTERFACE
ip link set \$INTERFACE down
EOF

chmod +x /etc/tinc/openwrt/tinc-up
chmod +x /etc/tinc/openwrt/tinc-down

cat << EOF > /etc/tinc/openwrt/hosts/glinet
Compression = 9
Subnet = 10.88.0.8/32
EOF

tincd -n openwrt -K

cat /etc/tinc/openwrt/rsa_key.pub >>  /etc/tinc/openwrt/hosts/glinet

# wireguard
iptables -A input_rule -s $vps_ip/32 -p tcp -m tcp --sport 8200 -m comment --comment "drop udp2raw_wg packets" -j DROP


