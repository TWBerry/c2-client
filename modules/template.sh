#!/usr/bin/env bash
# modules/my_module.sh

module_init() {
  URL="${1:-}"
  MODULE_OPT="${2:-default}"
  if [[ -z "$URL" ]]; then
    echo "[!] module_init: URL must be provided"
    return 1
  fi
  # další inicializace (např. remote tool detection)
}

send_cmd() {
  local CMD="$1"
  # vlastní transport (např. POST, log injection, redis)
  # např.: client_send_encrypted "$CMD"   # pokud chcete použít standardní encrypted transport z client.sh
}

module_main() {
  : # optional
}

module_description() {
  echo "My module — krátký popis"
}

show_module_help() {
  echo "Usage: <commands typed in REPL are passed to send_cmd>"
  echo "Example: id ; ls -la /tmp"
}
