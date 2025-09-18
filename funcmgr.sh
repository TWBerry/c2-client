#!/usr/bin/env bashfi
# --- funcmgr.sh (Functionality Manager) ---
# This file defines the central mechanism for registering functions inside modules.
# Each function exposed by a module is described with four parameters and stored
# into a global list (functions\_list). The client uses this list to know what
# commands are available, how many arguments they require, and how to describe them.
#
# Usage:
# register_function <command_name> <function_name> <param_count> <description>
#
# Parameters:
# command_name  - the operator command (string) that will be available in the REPL.
# function_name - the internal Bash function that should be called when command_name is invoked.
# param_count   - expected number of parameterss (not arguments - -c chunk_size is counted as 2 parameters) for this command.
# description   - short description text shown in command list.
#
# Example:
# register_function "net_local" "network_local_info" 0 "Show local network interfaces"
# register_function "sys_uname" "system_uname" 0 "Print kernel and OS information"
#
# After registration, these commands can be executed in the C2 client REPL by typing
# net_local
# sys_uname
#

register_function() {
  local command_name="$1"
  local function_name="$2"
  local param_count="$3"
  local description="$4"
  local row="${command_name} ${function_name} ${param_count} ${description}"$'\n'
  functions_list+=("$row")
}
