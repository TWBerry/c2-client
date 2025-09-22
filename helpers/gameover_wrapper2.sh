#!/bin/sh
u/python -c "import os;os.setuid(0);os.system('$*')"
