openssl dgst -md5 "$1" | awk '{print $2, " ", FILENAME}' FILENAME="$1"
