#!/bin/sh
# Usage:
#   ./b64helper.sh encode < infile > outfile.b64
#   ./b64helper.sh decode < infile.b64 > outfile
#   echo "test" | ./b64helper.sh encode | ./b64helper.sh decode

case "$1" in
  encode)
    # čte ze stdin a vypíše base64
    od -An -tx1 |
      tr -d ' \n' |
      fold -w76
    ;;
  decode)
    # čte ze stdin a převádí zpět
    tr -d '\n' |
      xxd -r -p
    ;;
  *)
    echo "Usage: $0 encode|decode" >&2
    exit 1
    ;;
esac
