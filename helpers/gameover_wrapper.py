#!/usr/bin/env python3
import os
import sys

os.setuid(0)
cmd = " ".join(sys.argv[1:])
os.execv("/bin/sh", ["/bin/sh", "-c", cmd])
