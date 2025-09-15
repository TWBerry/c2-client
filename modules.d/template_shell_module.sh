#!/usr/bin/env bash
# shell module skeleton (English)
# Module: example shell module
# Author: TWBerry (example)
# Note: this module assumes funcmgr.sh provides register_function and the framework provides send_cmd transport.

source funcmgr.sh

module_init() {
    # Example: first parameter is an URL or target identifier
    URL="${1:-}"
    MODULE_OPT="${2:-default}"

    if [[ -z "$URL" ]]; then
        echo "[!] module_init: URL must be provided"
        return 1
    fi

    # Additional initialization (e.g. detect available remote tools, set timeouts)
    # e.g. detect whether /dev/tcp is supported or whether curl/wget is available
    # This is a good place to register built-in extension functions using register_function
    # Example:
    # register_function "example_ping" "example_ping" 1 "Ping a remote host (via send_cmd)"
}

# send_cmd should route command text through the client's transport layer.
# Replace the body with the framework-specific transport call (POST, Redis injection, encrypted channel, etc.)
# Keep it minimal and safe: any escaping/encryption should be handled by the framework.
send_cmd() {
    local CMD="$1"
    if [[ -z "$CMD" ]]; then
        echo "[!] send_cmd: empty command"
        return 1
    fi

    # Example placeholders (uncomment and adapt to your framework):
    # client_send_encrypted "$CMD"
    # OR: printf '%s\n' "$CMD" | some_transport_tool --encrypt
    # For now we just print the command to stdout as a placeholder:
    printf '[send_cmd] %s\n' "$CMD"
}

module_main() {
    # Main entrypoint for the module.
    :
}

module_description() {
    echo "Example module — short description"
}

show_module_help() {
    cat <<'EOF'
Usage:
  Type commands in the REPL; each line will be passed to send_cmd.
Examples:
  id
  uname -a
  ls -la /tmp
Notes:
  - send_cmd is responsible for transporting and possibly encrypting the command.
  - For modules that expose multiple operator commands, use register_function in module_init.
EOF
}
