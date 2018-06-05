#!/bin/bash

#curl -sL http://f.ip.cn/rt/chnroutes.txt | egrep -v '^$|^#' > chnroute.txt
curl -sL http://www.ipdeny.com/ipblocks/data/countries/cn.zone > chnroute.txt
