#!/bin/sh
unshare -rm sh -c "mkdir -p l u w m && cp /u*/b*/$1 l/;
setcap cap_setuid+eip l/$1;mount -t overlay overlay -o rw,lowerdir=l,upperdir=u,workdir=w m && touch m/*;"
