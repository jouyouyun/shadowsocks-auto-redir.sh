#!/bin/bash

curl -sL http://f.ip.cn/rt/chnroutes.txt | egrep -v '^$|^#' > chnroute.txt
cat extra_white.txt >> chnroute.txt
