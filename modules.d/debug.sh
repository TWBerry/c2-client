#!/usr/bin/env bash
#c2-client module
#KPCdHbnTAV
#debug

source funcmgr.sh

print_warn() { echo -e "${YELLOW}[!]${NC} $1" >&2; }
print_err() { echo -e "${RED}[!]${NC} $1" >&2; }
print_std() { echo -e "${GREEN}[+]${NC} $1"; }
print_help() { echo -e "${BLUE}$1${NC} $2"; }
print_out() { echo -e "${GREEN}[+]${YELLOW} $1${NC}"; }

DEBUG_LOG_FILE="$HOME/debug.log"

# Wrapper function that logs each command
debug_wrapper() {
    local cmd="$1"
    # Timestamp for each entry
    local ts
    ts=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$ts] $cmd" >> "$DEBUG_LOG_FILE"
    # Return command unmodified for further wrappers
    echo "$cmd"
}

enable_debug() {
    print_std "Enabling debug wrapper..."
    register_cmd_wrapper "debug_wrapper"
    print_std "Debug wrapper enabled. Logging to $DEBUG_LOG_FILE"
    DEBUG="1"
}

disable_debug() {
    print_std "Disabling debug wrapper..."
    unregister_cmd_wrapper "debug_wrapper"
    print_std "Debug wrapper disabled."
    DEBUG="0"
}

KPCdHbnTAV_init() {
    # Register module functions (if needed)
    register_function "enable_debug" "enable_debug" 0 "Enable debug wrapper"
    register_function "disable_debug" "disable_debug" 0 "Disable debug wrapper"
    print_std "Enabling debug at startup..."
    enable_debug
}

KPCdHbnTAV_main() {
    :
}

KPCdHbnTAV_description() {
    echo "Debug wrapper module – logs all commands to debug.log"
}

KPCdHbnTAV_help() {
    print_help "enable_debug" "Enable debug wrapper (logs all commands)"
    print_help "disable_debug" "Disable debug wrapper"
}
