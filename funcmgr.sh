#!/usr/bin/env bash
# --- funcmgr.sh (Functionality Manager) ---
# Provides a system for registering REPL commands, handling command-line flags,
# and managing command wrappers. Also supports exit hooks for cleanup.

# ----------------------------------------------------------------------
# Function registration and command-line parameter handling
# ----------------------------------------------------------------------

# Register a REPL function provided by a module.
# usage: register_function <command_name> <function_name> <param_count> <description>
# - command_name: the REPL command the user will type
# - function_name: the Bash function that will be invoked
# - param_count: expected number of parameters
# - description: short help text
register_function() {
  local command_name="$1"
  local function_name="$2"
  local param_count="$3"
  local description="$4"
  local row="${command_name} ${function_name} ${param_count} ${description}"$'\n'
  functions_list+=("$row")
}

# Register a top-level command-line parameter with two callbacks.
# usage: register_cmdline_param <param> <present_callback> <missing_callback>
# - param: e.g. "-c" or "--chunk-size"
# - present_callback: function called if param is found
# - missing_callback: function called if param is not found
register_cmdline_param() {
  local cmdline_param="$1"
  local param_func_present="$2"
  local param_func_missing="$3"
  local row="${cmdline_param} ${param_func_present} ${param_func_missing}"$'\n'
  cmdline_list+=("$row")
}

# Process positional arguments ($@):
# - For each registered cmdline param:
#   → If present, call the "present" callback and remove it from args.
#   → If absent, call the "missing" callback.
# - Remaining args are stored in the global CMDLINE_REMAINING array.
CMDLINE_REMAINING=()
process_cmdline_params() {
  CMDLINE_REMAINING=() # reset previous contents
  if (($# == 0)); then
    return 0
  fi

  # Keep the first argument separately (often a subcommand)
  local first="$1"
  shift

  # Store remaining args in a temporary file
  local tmpfile
  tmpfile=$(mktemp)
  for arg in "$@"; do
    echo "$arg" >>"$tmpfile"
  done

  local cmdline_entry param present_func missing_func

  for cmdline_entry in "${cmdline_list[@]}"; do
    read -r param present_func missing_func <<<"$cmdline_entry"
    if grep -qxE "^$param$" "$tmpfile"; then
      # Parameter is present → call "present" callback
      declare -f "$present_func" >/dev/null && "$present_func" >&2
      # Remove all occurrences from tmpfile
      sed -i "/^$param$/d" "$tmpfile"
    else
      # Parameter is missing → call "missing" callback
      declare -f "$missing_func" >/dev/null && "$missing_func" >&2
    fi
  done

  # Store the remaining args
  CMDLINE_REMAINING=("$first")
  while IFS= read -r line; do
    [[ -n "$line" ]] && CMDLINE_REMAINING+=("$line")
  done <"$tmpfile"
  rm -f "$tmpfile"
}

# ----------------------------------------------------------------------
# Command wrapper management
# ----------------------------------------------------------------------
# Command wrappers are functions that intercept/modify commands before they
# are executed. They are applied in priority order.

if [[ -z "${FUNCMGR:-}" ]]; then
  FUNCMGR="1"
  declare -A CMD_WRAPPERS_PRIORITY   # key = wrapper function name, value = priority
  declare -a CMD_WRAPPERS_ORDER      # list of wrapper names in registration order
fi

# Register a command wrapper with optional priority.
# Lower priority numbers are executed first.
# usage: register_cmd_wrapper <function_name> [priority]
register_cmd_wrapper() {
    local func_name="$1"
    local priority="${2:-1000}"   # default priority = 1000
    CMD_WRAPPERS_PRIORITY["$func_name"]="$priority"

    # Only add to order list if not already present
    for w in "${CMD_WRAPPERS_ORDER[@]}"; do
        [[ "$w" == "$func_name" ]] && return
    done
    CMD_WRAPPERS_ORDER+=("$func_name")
}

# Get list of wrappers sorted by priority
get_wrappers_sorted() {
    local sorted
    sorted=$(for w in "${CMD_WRAPPERS_ORDER[@]}"; do
        echo "$w ${CMD_WRAPPERS_PRIORITY[$w]}"
    done | sort -k2n | awk '{print $1}')
    echo "$sorted"
}

# Apply all registered wrappers in order to a command
cmd_wrapper() {
    local cmd="$*"
    local w
    for w in $(get_wrappers_sorted); do
        cmd=$("$w" "$cmd")
    done
    echo "$cmd"
}

# Unregister a previously registered command wrapper
unregister_cmd_wrapper() {
    local func_name="$1"

    # Remove from priority map
    unset 'CMD_WRAPPERS_PRIORITY["$func_name"]'

    # Rebuild order list without this wrapper
    local new_list=()
    for w in "${CMD_WRAPPERS_ORDER[@]}"; do
        [[ "$w" == "$func_name" ]] || new_list+=("$w")
    done
    CMD_WRAPPERS_ORDER=("${new_list[@]}")
}

# ----------------------------------------------------------------------
# Exit hook management
# ----------------------------------------------------------------------

# Register a function to be called on program exit
register_exit_func() {
  local fn="$1"
  EXIT_FUNCS+=("$fn")
}

# Run all registered exit functions
run_exit_funcs() {
  for fn in "${EXIT_FUNCS[@]}"; do
    "$fn"
  done
}

# Ensure exit functions are executed on normal program termination
trap run_exit_funcs EXIT
