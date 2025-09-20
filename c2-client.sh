#!/usr/bin/env bash
set -euo pipefail
shopt -s histappend
HISTORY_FILE="${HOME}/.c2_client_history"
export HISTFILE="$HISTORY_FILE"
export HISTSIZE=1000
export HISTFILESIZE=2000

# Color definitions for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

main_loop_command=""
VERSION="1.1.0"
source "funcmgr.sh"
# Check if readline is available
check_readline() {
    if ! bind -V >/dev/null 2>&1; then
        echo -e "${YELLOW}[!]${NC} Readline not available. Using basic input without history."
        return 1
    fi
    return 0
}

# Initialize readline and history
init_readline() {
    if check_readline; then
        # Enable arrow key navigation
        bind '"\e[A": history-search-backward' 2>/dev/null
        bind '"\e[B": history-search-forward' 2>/dev/null
        bind '"\e[C": forward-char' 2>/dev/null
        bind '"\e[D": backward-char' 2>/dev/null

        # Load or create history
        [[ -f "$HISTFILE" ]] || touch "$HISTFILE"
        history -r "$HISTFILE"
        LAST_COMMAND=$(history | tail -n 1 | sed 's/^[ ]*[0-9]*[ ]*//')
    fi
}


# Save command to history
save_to_history() {
    local command="$1"
    if check_readline && [[ -n "$command" ]]; then
        if [[ "$command" != "$LAST_COMMAND" ]]; then
            history -s "$command"
            history -a
            LAST_COMMAND="$command"
        fi
    fi
}


# Enhanced read with history support
read_with_history() {
    local line
    
    if check_readline; then
        # Use read -e for readline support
        read -rep "$user@$hostname>" line
        # Add to history
        save_to_history "$line"
    else
        # Fallback to basic read
        read -rp "$user@$hostname>" line
    fi
    
    echo "$line"
}

# Print available command list with descriptions
print_command_list() {
  echo -e "${GREEN}local <cmd> ${NC}- ${YELLOW}Execute command locally"
  echo -e "${GREEN}helpme ${NC}- ${YELLOW}Show help information"
  echo -e "${GREEN}show_cmd ${NC}- ${YELLOW}Display this command list"
  echo -e "${GREEN}history ${NC}- ${YELLOW}Show command history"
  echo -e "${GREEN}clear_history ${NC}- ${YELLOW}Clear command history"
  echo -e "${GREEN}<cmd> ${NC}- ${YELLOW}Execute command remotely"
  echo -e "${GREEN}exit ${NC}- ${YELLOW}Exit the client"

  # Display all registered functions from function manager
  for line in "${functions_list[@]}"; do
    read -r w1 w2 w3 w4 <<<"$line"
    echo -e "${GREEN}$w1 ${NC}- ${YELLOW}$w4"
  done
}

# Show command history
show_history() {
    if [[ -f "$HISTORY_FILE" ]]; then
        echo -e "${GREEN}Command history:${NC}"
        cat -n "$HISTORY_FILE" | tail -20
    else
        echo -e "${YELLOW}No history found${NC}"
    fi
}

# Clear command history
clear_history() {
    if [[ -f "$HISTORY_FILE" ]]; then
        > "$HISTORY_FILE"
        echo -e "${GREEN}History cleared${NC}"
    else
        echo -e "${YELLOW}No history to clear${NC}"
    fi
}

# Execute command locally on the client machine
local_cmd() {
  eval "$*"
}

# Load all modules specified in the modules file
load_modules() {
  echo -e "${GREEN}[+]${NC} Loading modules..."

  while IFS= read -r mod || [[ -n "$mod" ]]; do
    [[ -z "$mod" ]] && continue # Skip empty lines

    local file="./modules.d/$mod.sh"
    if [[ ! -f "$file" ]]; then
      echo -e "${RED}[!]${NC} Module file $file not found, skipping"
      continue
    fi

    source "$file"

    # Extract module ID from third line of module file
    local id_line
    id_line=$(sed -n '3p' "$file")
    local id=${id_line#\#}

    # Check for required module functions
    local required_funcs=("${id}_init" "${id}_description")
    local missing=0
    for fn in "${required_funcs[@]}"; do
      if ! declare -f "$fn" >/dev/null; then
        echo -e "${RED}[!]${NC} Module $mod is missing required function: $fn"
        missing=1
      fi
    done
    ((missing)) && continue

    # Initialize the module
    "${id}_init"

    echo -e "${GREEN}[+]${NC} Module $mod loaded."
    "${id}_description"
  done <modules
}

# Main execution function
main() {
  # Initialize readline
  init_readline
  # Check connection by getting remote username
  user=$(send_cmd "whoami")
  if [[ -z "$user" ]]; then
    echo -e "${RED}[+]${NC} Failed to connect to $URL"
    exit 1
  else
    echo -e "${NC}Connected to ${BLUE}$URL ${NC} as ${BLUE}$user${NC}"
    hostname=$(send_cmd "hostname")
  fi

  # Execute main function of each loaded module
  while IFS= read -r mod || [[ -n "$mod" ]]; do
    [[ -z "$mod" ]] && continue
    local file="./modules.d/$mod.sh"
    [[ ! -f "$file" ]] && continue

    local id_line
    id_line=$(sed -n '3p' "$file")
    local id=${id_line#\#}

    local func="${id}_main"
    if declare -f "$func" >/dev/null; then
      "$func"
    else
      echo -e "${YELLOW}[!]${NC} Module $mod has no $func, skipping"
    fi
  done <modules

  print_command_list
  eval "$main_loop_command"
}

# Assemble the main command loop structure
assemble_main_loop() {
  echo -e "${GREEN}[+]${NC} Assembling main loop..."
  main_loop_command+='while true; do'$'\n'
  main_loop_command+='  echo -ne "${BLUE}"'$'\n'
  main_loop_command+='  LINE=$(read_with_history)'$'\n'
  main_loop_command+='  echo -ne "${NC}"'$'\n'
  main_loop_command+='  [[ "$LINE" == "exit" ]] && break'$'\n'
  #main_loop_command+='  save_to_history "$LINE" '$'\n'
  main_loop_command+='  set -- $LINE'$'\n'
  main_loop_command+='  case "$1" in'$'\n'

  # Local command case
  main_loop_command+='    local)'$'\n'
  main_loop_command+='      shift'$'\n'
  main_loop_command+='      local_cmd "$*"'$'\n'
  main_loop_command+='      ;;'$'\n'

  # History commands
  main_loop_command+='    history)'$'\n'
  main_loop_command+='      show_history'$'\n'
  main_loop_command+='      ;;'$'\n'
  
  main_loop_command+='    clear_history)'$'\n'
  main_loop_command+='      clear_history'$'\n'
  main_loop_command+='      ;;'$'\n'

  # Add all registered functions to the case statement
  for line in "${functions_list[@]}"; do
    read -r w1 w2 w3 w4 <<<"$line"
    main_loop_command+="    $w1)"$'\n'
    if ((w3 > 0)); then
      main_loop_command+='      shift'$'\n'
      main_loop_command+="      $w2 \"\${@:1:$w3}\""$'\n'
    else
      main_loop_command+="      $w2"$'\n'
    fi
    main_loop_command+='      ;;'$'\n'
  done

  # Help and command list cases
  main_loop_command+='      helpme) show_help ;;'$'\n'
  main_loop_command+='      show_cmd) print_command_list ;;'$'\n'
  main_loop_command+='      *) send_cmd "$*" ;;'$'\n' # Default case: send command remotely
  main_loop_command+='  esac'$'\n'
  main_loop_command+='done'$'\n'
}

# Display main help information
show_help2() {
  echo -e "${BLUE}C2 Client version v$VERSION${NC}"
  echo -e "Usage: $0 <shell_module> <url> [shell_module_args]"
}

# Display comprehensive help including module-specific help
show_help() {
  show_module_help
  local list=$(cat modules)
  for line in $list; do
    local file="./modules.d/$line.sh"
    source "$file"
    local line=$(sed -n '3p' "$file")
    local id=${line#\#}
    local func="${id}_help"
    eval "$func"
  done
}

# Handle command line arguments
if [[ "$#" -eq 0 || "$1" == "--help" || "$1" == "-h" ]]; then
  show_help2
  exit 0
fi

if [[ "$1" == "--version" || "$1" == "-v" ]]; then
  echo -e "${BLUE}C2 Client v$VERSION${NC}"
  exit 0
fi

# Load and validate the shell module
SHELL_MODULE_NAME="${1:-template_shell_module}"
SHELL_MODULE_PATH="./modules.d/${SHELL_MODULE_NAME}.sh"

if [[ ! -f "$SHELL_MODULE_PATH" ]]; then
  echo -e "${RED}[!] ${NC}Shell module $SHELL_MODULE_NAME not found"
  exit 1
fi

source "$SHELL_MODULE_PATH"
# Validate that the shell module has all required functions
for fn in module_init module_main send_cmd module_description show_module_help; do
  if ! declare -f "$fn" >/dev/null; then
    echo -e "${RED}[!] ${NC}Shell module $SHELL_MODULE_NAME is missing function $fn"
    exit 1
  fi
done

shift

# Show module-specific help if requested
if [[ "$#" -eq 0 || "$1" == "--help" || "$1" == "-h" ]]; then
  show_module_help
  exit 0
fi

# Initialize the module and start the main program

load_modules
remaining_args=$(process_cmdline_params "$@")
module_init $remaining_args
echo -e "${GREEN}[+] ${NC}Loaded shell module: $SHELL_MODULE_NAME"
module_description
assemble_main_loop
main
