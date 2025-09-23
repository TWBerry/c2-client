#!/usr/bin/env bash
# --- funcmgr.sh (Functionality Manager) ---
# Manage registration of functions and processing of command-line parameters.
# - register_function: registers REPL commands provided by modules
# - register_cmdline_param: registers top-level flags (e.g. -c, --help) with
#   callbacks for present/missing handling
# - process_cmdline_params: inspects $@, invokes callbacks, and stores the
#   remaining (unprocessed) args in a global variable.

# Register a REPL function provided by a module
# usage: register_function <command_name> <function_name> <param_count> <description>
register_function() {
  local command_name="$1"
  local function_name="$2"
  local param_count="$3"
  local description="$4"
  local row="${command_name} ${function_name} ${param_count} ${description}"$'\n'
  functions_list+=("$row")
}

# Register a top-level command-line parameter with two callbacks:
# usage: register_cmdline_param <param> <present_callback> <missing_callback>
# param example: -c or --chunk-size
register_cmdline_param() {
  local cmdline_param="$1"
  local param_func_present="$2"
  local param_func_missing="$3"
  local row="${cmdline_param} ${param_func_present} ${param_func_missing}"$'\n'
  cmdline_list+=("$row")
}

# Process positional arguments ($@):
# - For each registered cmdline param, search and remove occurrences from the
#   provided args. If found, call the present callback. If not found, call
#   the missing callback.
# - Remaining args (unprocessed) are stored in the global array CMDLINE_REMAINING.
CMDLINE_REMAINING=()
process_cmdline_params() {
  CMDLINE_REMAINING=() # clear previous contents
  if (($# == 0)); then
    return 0
  fi

  # keep the first argument separately
  local first="$1"
  shift
  # temporary file for arguments
  local tmpfile
  tmpfile=$(mktemp)
  for arg in "$@"; do
    echo "$arg" >>"$tmpfile"
  done

  local cmdline_entry param present_func missing_func

  for cmdline_entry in "${cmdline_list[@]}"; do
    read -r param present_func missing_func <<<"$cmdline_entry"
    if grep -qxE "^$param$" "$tmpfile"; then
      # parameter is present
      declare -f "$present_func" >/dev/null && "$present_func" >&2
      # remove all occurrences of the parameter from the file
      sed -i "/^$param$/d" "$tmpfile"
    else
      # parameter is missing
      declare -f "$missing_func" >/dev/null && "$missing_func" >&2
    fi
  done

  # store the result in the global variable
  CMDLINE_REMAINING=("$first")
  while IFS= read -r line; do
    [[ -n "$line" ]] && CMDLINE_REMAINING+=("$line")
  done <"$tmpfile"
  rm -f "$tmpfile"
}

# --- Command wrapper management ---

# --- Chained command wrappers ---
if [[ -z "${FUNCMGR:-}" ]]; then
FUNCMGR="1"
declare -A CMD_WRAPPERS_PRIORITY   # klíč = název wrapperu, hodnota = priorita
declare -a CMD_WRAPPERS_ORDER      # seznam wrapperů v pořadí registrace
fi

register_cmd_wrapper() {
    local func_name="$1"
    local priority="${2:-1000}"   # default priority 1000, debug/dir mohou mít 999/1000
    CMD_WRAPPERS_PRIORITY["$func_name"]="$priority"
    # Přidat do seznamu, pokud ještě není
    for w in "${CMD_WRAPPERS_ORDER[@]}"; do
        [[ "$w" == "$func_name" ]] && return
    done
    CMD_WRAPPERS_ORDER+=("$func_name")
}

# Funkce na získání seznamu wrapperů seřazených podle priority
get_wrappers_sorted() {
    local sorted
    sorted=$(for w in "${CMD_WRAPPERS_ORDER[@]}"; do
        echo "$w ${CMD_WRAPPERS_PRIORITY[$w]}"
    done | sort -k2n | awk '{print $1}')
    echo "$sorted"
}

# Wrapper handler
cmd_wrapper() {
    local cmd="$*"
    local w
    for w in $(get_wrappers_sorted); do
        cmd=$("$w" "$cmd")
    done
    echo "$cmd"
}

unregister_cmd_wrapper() {
    local func_name="$1"

    # Vymazat z priority mapy
    unset 'CMD_WRAPPERS_PRIORITY["$func_name"]'

    # Přefiltrovat order pole bez daného wrapperu
    local new_list=()
    for w in "${CMD_WRAPPERS_ORDER[@]}"; do
        [[ "$w" == "$func_name" ]] || new_list+=("$w")
    done
    CMD_WRAPPERS_ORDER=("${new_list[@]}")
}

register_exit_func() {
  local fn="$1"
  EXIT_FUNCS+=("$fn")
}

# Trap to call all registered exit functions on normal exit
run_exit_funcs() {
  for fn in "${EXIT_FUNCS[@]}"; do
    "$fn"
  done
}

trap run_exit_funcs EXIT
