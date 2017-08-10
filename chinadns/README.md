# 使用 `chinadns` 来避免 DNS 污染

来源与: [ss-redir透明代理](https://www.zfl9.com/ss-redir.html)

## 安装 `chinadns`
```shell
wget https://github.com/shadowsocks/ChinaDNS/releases/download/1.3.2/chinadns-1.3.2.tar.gz
tar xf chinadns-1.3.2.tar.gz
cd chinadns-1.3.2
./configure && make
cp -af src/chinadns /usr/local/bin/chinadns
mkdir -p /etc/chinadns/
cp -af chnroute.txt /etc/chinadns/
cp -af iplist.txt /etc/chinadns/
```

## 更新大陆 IP
```shell
#!/bin/bash

cd $(cd $(dirname $0); pwd)
rm -fr ipset.chinaip.*

echo 'create chinaip hash:net' > ipset.chinaip.`date +%F_%T`

for ip in `curl -sL http://f.ip.cn/rt/chnroutes.txt | egrep -v '^\s*$|^\s*#'`; do
    echo "add chinaip $ip" >> ipset.chinaip.*
done
```

## 配置 iptables
```shell
#!/bin/bash

cd $(cd $(dirname $0); pwd)
rm -fr iptables.shadowsocks.*

cat << EOF > iptables.shadowsocks.`date +%F_%T`
*nat
:shadowsocks -
-A shadowsocks -d 0/8 -j RETURN
-A shadowsocks -d 127/8 -j RETURN
-A shadowsocks -d 10/8 -j RETURN
-A shadowsocks -d 169.254/16 -j RETURN
-A shadowsocks -d 172.16/12 -j RETURN
-A shadowsocks -d 192.168/16 -j RETURN
-A shadowsocks -d 224/4 -j RETURN
-A shadowsocks -d 240/4 -j RETURN
-A shadowsocks -d $1 -j RETURN
-A shadowsocks -m set --match-set chinaip dst -j RETURN
-A shadowsocks ! -p icmp -j REDIRECT --to-ports $2
-A OUTPUT ! -p icmp -j shadowsocks
COMMIT
EOF

if [ ! -e iptables.nat.clean ]; then
    echo -e "*nat\nCOMMIT" > iptables.nat.clean
fi
```

## 控制 shadowsocks
```shell
#!/bin/bash

ss_server=你的ss服务器ip或域名
ss_port=ss服务器端口号
ss_method=加密方式
ss_pass=密码
listen_port=1080
dns_listen_port=1053
dns_upstream=114.114.114.114,127.0.0.1:${dns_listen_port}

case $1 in
start)
    nohup ss-redir -s ${ss_server} -p ${ss_port} -m ${ss_method} -k ${ss_pass} -u -b '0.0.0.0' -l ${listen_port} -v &>> /var/log/ss-redir.log &
    nohup ss-tunnel -s ${ss_server} -p ${ss_port} -m ${ss_method} -k ${ss_pass} -u -b '0.0.0.0' -l ${dns_listen_port} -L '8.8.8.8:53' -v &>> /var/log/ss-tunnel.log &
    nohup chinadns -c /etc/chinadns/chnroute.txt -l /etc/chinadns/iplist.txt -b 0.0.0.0 -p 53 -s ${dns_upstream} -d -v &>> /var/log/chinadns.log &
    ipset -R < $(cd $(dirname $0); pwd)/ipset.chinaip.*
    iptables-restore < $(cd $(dirname $0); pwd)/iptables.shadowsocks.*
    ;;
stop)
    iptables-restore < $(cd $(dirname $0); pwd)/iptables.nat.clean
    ipset -X chinaip &> /dev/null
    kill -9 `ps -ef | egrep '\schinadns\s' | egrep -v 'grep' | awk '{print $2}'` &> /dev/null
    kill -9 `ps -ef | egrep '\sss-redir\s' | egrep -v 'grep' | awk '{print $2}'` &> /dev/null
    kill -9 `ps -ef | egrep '\sss-tunnel\s' | egrep -v 'grep' | awk '{print $2}'` &> /dev/null
    ;;
*)
    echo "usage: $(cd $(dirname $0); pwd)/shadowsocks.sh start|stop"
    exit 1
    ;;
esac
```

## Usage

+ 首次运行请先执行./ipset_chinaip、./iptables_shadowsocks SS_IP LISTEN_PORT(如: ./iptables_shadowsocks 1.2.3.4 1080)
端口号建议统一：ss-redir:1080、ss-tunnel:1053、chinadns:53

+ 设置dns解析，/etc/resolv.conf，dns为127.0.0.1，注意某些系统在重启后会自动更改dns设置，请注意该问题！

+ 启用shadowsocks：./shadowsocks.sh start

+ 关闭shadowsocks：./shadowsocks.sh stop

+ 相关日志：/var/log/ss-redir.log、/var/log/ss-tunnel.log、/var/log/chinadns.log

+ 测试是否全局代理成功：curl -sL www.google.com

+ 查看当前IP：curl -sL ip.cn

+ 更新大陆ip段：./ipset_chinaip，然后重启shadowsocks：./shadowsocks.sh stop && ./shadowsocks.sh start

+ 更新iptables规则：./iptables_shadowsocks SS_IP LISTEN_PORT，然后重启shadowsocks：./shadowsocks.sh stop && ./shadowsocks.sh start

关于第2点，设置dns的，再说一次，请尽量在ss-redir和ss-tunnel中填写ss服务器的ip，不要填域名！
不然会因为解析不到ss服务器的ip，导致ss-redir和ss-tunnel启动失败！
