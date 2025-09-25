#!/usr/bin/env bash
# helpers/example.sh - example helper for example.c2
#
# Notes:
# - Intended to be uploaded and executed on the remote system.
# - Demonstrates that the upload_and_run helper in example.c2 script works correctly.

echo "Hello from test.sh!"
echo "Current working directory: $(pwd)"
echo "Listing files in current directory:"
ls -la

# Optional: create a small test file to demonstrate write access
echo "This is a test file created by test.sh" > test_output.txt
echo "Created test_output.txt"

# End of test.sh

