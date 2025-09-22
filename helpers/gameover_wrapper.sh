#!/bin/sh
u/python3 -c "import os;os.setuid(0);os.system('$*')"
