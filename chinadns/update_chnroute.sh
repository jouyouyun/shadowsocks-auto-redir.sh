#!/bin/bash

cd $(cd $(dirname $0); pwd)
rm -fr ipset.chinaip.*

echo 'create chinaip hash:net' > ipset.chinaip.`date +%F_%T`

for ip in `curl -sL http://f.ip.cn/rt/chnroutes.txt | egrep -v '^\s*$|^\s*#'`; do
    echo "add chinaip $ip" >> ipset.chinaip.*
done
