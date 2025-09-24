#!/usr/bin/env bash
#c2-client module
#AsrirGGxuI
#dir (virtual directory handler)

source funcmgr.sh

# Print warning message in yellow
print_warn() {
  echo -e "${YELLOW}[!]${NC} $1" >&2
}

# Print error message in red
print_err() {
  echo -e "${RED}[!]${NC} $1" >&2
}

# Print standard message in green
print_std() {
  echo -e "${GREEN}[+]${NC} $1"
}

# Print help message with blue command and normal description
print_help() {
  echo -e "${BLUE}$1${NC} $2"
}

# Print output message with green prefix and yellow content
print_out() {
  echo -e "${GREEN}[+]${YELLOW} $1${NC}"
}

# Debug print function (if DEBUG is set to 1, log to debug file)
print_dbg() {
  if [[ "${DEBUG}" == "1" ]]; then
    local ts
    ts=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$ts] $1" >> "$DEBUG_LOG_FILE"
  fi
}

# Change virtual directory
dir_cd() {
    # Assign empty value if $1 is not set
    local target="${1:-}"
    
    # If no parameter given, do nothing
    [[ -z "$target" ]] && return 0
    
    local new_dir=""

    case "$target" in
        ..|/..)
            # Move up one directory
            new_dir=$(dirname "$CURRENT_DIR")
            ;;
        .|/.)
            # Stay in the same directory – do nothing
            return 0
            ;;
        /*)
            # Absolute path
            new_dir="$target"
            ;;
        *)
            # Relative path
            if ! [[ $CURRENT_DIR == "/" ]]; then
              new_dir="$CURRENT_DIR/$target"
            else
              new_dir="$CURRENT_DIR$target"
            fi
            ;;
    esac

    # Verify if the directory exists on the remote system
    if send_cmd "[ -d \"$new_dir\" ] && echo yes || echo no" | grep -q "yes"; then
        CURRENT_DIR="$new_dir"
        print_dbg "Changed directory to $CURRENT_DIR"
    else
        print_err "Directory $new_dir does not exist on target"
    fi
}

# Return the current virtual directory
dir_pwd() {
  echo "$CURRENT_DIR"
}

# Command wrapper function – prepend 'cd $CURRENT_DIR' to each command
dir_wrapper() {
    local cmd="$*"
    echo "cd $CURRENT_DIR && $cmd"
}

# Module initialization function
AsrirGGxuI_init() {
    register_function "cd" "dir_cd" 1 "change remote directory"
    register_function "pwd" "dir_pwd" 0 "print remote working directory"
}

# Module main function – initialize CURRENT_DIR from remote system
AsrirGGxuI_main() {
    CURRENT_DIR=$(send_cmd "pwd")
    register_cmd_wrapper dir_wrapper 999   # register wrapper with priority 999
    print_std "Directory wrapper initialized. Starting in $CURRENT_DIR"
}

# Module description
AsrirGGxuI_description() {
    echo "Maintains virtual working directory across commands"
}

# Module help function
AsrirGGxuI_help() {
    :
}
