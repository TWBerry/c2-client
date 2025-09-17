#!/usr/bin/env python3
import sys, hashlib, os

if len(sys.argv) < 2:
    sys.stderr.write(f"Usage: {sys.argv[0]} <file>\n")
    sys.exit(1)

fname = sys.argv[1]
if not os.path.isfile(fname):
    sys.stderr.write("File not found\n")
    sys.exit(1)

with open(fname, "rb") as f:
    data = f.read()
hashval = hashlib.md5(data).hexdigest()
print(f"{hashval}  {fname}")
