#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
main_loop_command=""
VERSION="1.0.0"
source "funcmgr.sh"

print_command_list() {
	echo -e "${GREEN}local <cmd> ${NC}- ${YELLOW}Local command"
	echo -e "${GREEN}helpme ${NC}- ${YELLOW}Show help"
	echo -e "${GREEN}show_cmd ${NC}- ${YELLOW}Show this command list"
	echo -e "${GREEN}<cmd> ${NC}- ${YELLOW}Remote command"
	echo -e "${GREEN}exit ${NC}- ${YELLOW}Exit the client"
	for line in "${functions_list[@]}"; do
		read -r w1 w2 w3 w4 <<<"$line"
		echo -e "${GREEN}$w1 ${NC}- ${YELLOW}$w4"
	done
}

local_cmd() {
	eval "$*"
}

load_modules() {
	echo -e "${GREEN}[+]${NC} Loading modules..."

	while IFS= read -r mod || [[ -n "$mod" ]]; do
		[[ -z "$mod" ]] && continue # přeskoč prázdné řádky

		local file="./modules.d/$mod.sh"
		if [[ ! -f "$file" ]]; then
			echo -e "${RED}[!]${NC} Module file $file not found, skipping"
			continue
		fi

		source "$file"

		# třetí řádek obsahuje ID
		local id_line
		id_line=$(sed -n '3p' "$file")
		local id=${id_line#\#}

		# seznam povinných funkcí pro modul
		local required_funcs=("${id}_init" "${id}_description")
		local missing=0
		for fn in "${required_funcs[@]}"; do
			if ! declare -f "$fn" >/dev/null; then
				echo -e "${RED}[!]${NC} Module $mod is missing required function: $fn"
				missing=1
			fi
		done
		((missing)) && continue

		# spustíme init
		"${id}_init"

		echo -e "${GREEN}[+]${NC} Module $mod loaded."
		"${id}_description"
	done <modules
}

main() {
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

assemble_main_loop() {
	echo -e "${GREEN}[+]${NC} Assembling main loop..."
	main_loop_command+='while true; do'$'\n'
	main_loop_command+='  echo -ne "${BLUE}"'$'\n'
	main_loop_command+='  read -rp "$user> " LINE'$'\n'
	main_loop_command+='  echo -ne "${NC}"'$'\n'
	main_loop_command+='  [[ "$LINE" == "exit" ]] && break'$'\n'
	main_loop_command+='  set -- $LINE'$'\n'
	main_loop_command+='  case "$1" in'$'\n'
	main_loop_command+='    local)'$'\n'
	main_loop_command+='      shift'$'\n'
	main_loop_command+='      local_cmd "$*"'$'\n'
	main_loop_command+='      ;;'$'\n'
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

	main_loop_command+='      helpme) show_help ;;'$'\n'
	main_loop_command+='      show_cmd) print_command_list ;;'$'\n'
	main_loop_command+='      *) send_cmd "$*" ;;'$'\n'
	main_loop_command+='  esac'$'\n'
	main_loop_command+='done'$'\n'
}

show_help() {
	echo -e "${BLUE}C2 Client version v$VERSION${NC}"
	echo -e "Usage: $0 <shell_module> <url> [shell_module_args]"
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

if [[ "$#" -eq 0 || "$1" == "--help" || "$1" == "-h" ]]; then
	show_help
	exit 0
fi

if [[ "$1" == "--version" || "$1" == "-v" ]]; then
	echo -e "${BLUE}C2 Client v$VERSION${NC}"
	exit 0
fi

SHELL_MODULE_NAME="${1:-sample_module}"
SHELL_MODULE_PATH="./modules.d/${SHELL_MODULE_NAME}.sh"

if [[ ! -f "$SHELL_MODULE_PATH" ]]; then
	echo -e "${RED}[!] ${NC}Shell module $SHELL_MODULE_NAME not found"
	exit 1
fi

source "$SHELL_MODULE_PATH"
for fn in module_init module_main send_cmd module_description show_module_help; do
	if ! declare -f "$fn" >/dev/null; then
		echo -e "${RED}[!] ${NC}Shell module $SHELL_MODULE_NAME is missing function $fn"
		exit 1
	fi
done

shift

if [[ "$#" -eq 0 || "$1" == "--help" || "$1" == "-h" ]]; then
	show_module_help
	exit 0
fi

module_init "$@"
echo -e "${GREEN}[+] ${NC}Loaded shell module: $SHELL_MODULE_NAME"
module_description
load_modules
assemble_main_loop
user=$(send_cmd "whoami")
if [[ -z "$user" ]]; then
	echo -e "${RED}[+]${NC} Failed to connect to $URL"
else
	echo -e "${NC}Connected to ${BLUE}$URL ${NC} as ${BLUE} $user"
fi
main
