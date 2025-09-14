#!/usr/bin/env python3
# b64helper.py
import sys, base64
if len(sys.argv) < 2:
    sys.stderr.write("Usage: python3 b64helper.py encode|decode\n"); sys.exit(1)
mode = sys.argv[1]
data = sys.stdin.buffer.read()
if mode == 'encode':
    sys.stdout.write(base64.b64encode(data).decode('ascii'))
elif mode == 'decode':
    try:
        sys.stdout.buffer.write(base64.b64decode(data))
    except Exception:
        sys.stderr.write("Bad base64\n"); sys.exit(2)
else:
    sys.stderr.write("Usage: python3 b64helper.py encode|decode\n"); sys.exit(1)
