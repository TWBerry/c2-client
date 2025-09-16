#!/bin/sh
#   ./b64helper.sh encode < infile > outfile.b64
#   ./b64helper.sh decode < infile.b64 > outfile

case "$1" in
encode)
	shift
	if [[ -z "$1" ]]; then
		od -An -tx1 | tr -d ' \n' | fold -w76 | sed 's/.*/&/'
	else
		cat "$1" | od -An -tx1 | tr -d ' \n' | fold -w76 | sed 's/.*/&/'
	fi
	;;
decode)
	shift
	if [[ -z "$1" ]]; then
		tr -d '\n' | xxd -r -p
	else
		cat "$1" | tr -d '\n' | xxd -r -p
	fi
	;;
*)
	echo "Usage: $0 encode|decode [file]" >&2
	exit 1
	;;
esac
