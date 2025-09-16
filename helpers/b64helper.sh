#!/bin/sh
# b64helper-sh encode|decode
cmd="$1"
if [ "$cmd" = "encode" ]; then
	openssl enc -base64 | tr -d '\n'
elif [ "$cmd" = "decode" ]; then
	awk '{gsub(/.{76}/,"&\n")}1' | openssl enc -d -base64
else
	echo "Usage: $0 encode|decode" >&2
	exit 1
fi
