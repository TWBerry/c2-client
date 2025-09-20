#!/usr/bin/env bash
# --- funcmgr.sh (Functionality Manager) ---
# Manage registration of commands and processing of command-line parameters.
# - register_function registers REPL commands provided by modules
# - register_cmdline_param registers top-level flags (e.g. -c, --help) with
#   callbacks for present/missing handling
# - process_cmdline_params inspects $@, invokes callbacks and returns the
#   remaining (unprocessed) args as a whitespace-separated string.

# register a REPL function provided by a module
# usage: register_function <command_name> <function_name> <param_count> <description>
register_function() {
  local command_name="$1"
  local function_name="$2"
  local param_count="$3"
  local description="$4"
  local row="${command_name} ${function_name} ${param_count} ${description}"$'\n'
  functions_list+=("$row")
}

# register a top-level command-line parameter with two callbacks:
#  register_cmdline_param <param> <present_callback> <missing_callback>
# param example: -c or --chunk-size
register_cmdline_param() {
  local cmdline_param="$1"
  local param_func_present="$2"
  local param_func_missing="$3"
  local row="${cmdline_param} ${param_func_present} ${param_func_missing}"$'\n'
  cmdline_list+=("$row")
}

# Process positional args ($@):
# - For each registered cmdline param, search and remove occurrences from the
#   provided args. If a value is present (either as next token or as = form),
#   pass it to the present callback. If param not found, call missing callback.
# Returns remaining args (unprocessed) as single-line whitespace-separated string.
process_cmdline_params() {
    if (( $# == 0 )); then
        echo
        return 0
    fi
    echo -n "$1"
    shift

    # dočasný soubor pro argumenty
    local tmpfile
    tmpfile=$(mktemp)
    for arg in "$@"; do
        echo "$arg" >> "$tmpfile"
    done

    local cmdline_entry param present_func missing_func

    for cmdline_entry in "${cmdline_list[@]}"; do
         read -r param present_func missing_func <<< "$cmdline_entry"
        if grep -qxE "^$param$" "$tmpfile"; then
            # parametr je přítomen
            declare -f "$present_func" >/dev/null && "$present_func" >&2
            # smažeme všechny výskyty parametru ze souboru
            sed -i "/^$param$/d" "$tmpfile"
        else
            # parametr chybí
            declare -f "$missing_func" >/dev/null && "$missing_func" >&2
        fi
    done

    while IFS= read -r line; do
        echo -n " $line"
    done < "$tmpfile"

    rm -f "$tmpfile"
}
