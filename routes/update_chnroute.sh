#!/bin/bash

curl -sL http://f.ip.cn/rt/chnroutes.txt | egrep -v '^$|^#' > chnroute.txt
