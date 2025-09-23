#!/usr/bin/env python3
import os
import sys
import subprocess

os.setuid(0)
cmd = sys.argv[1:]
subprocess.run(cmd, check=False)
