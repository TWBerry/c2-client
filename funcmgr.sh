#!/bin/bash
#Funcionality manager

register_function() {
  local command_name="$1"
  local function_name="$2"
  local arg_count="$3"
  local description="$4"
  local row="${command_name} ${function_name} ${arg_count} ${description}"$'\n'
  functions_list+=("$row")
}
