#!/usr/bin/env bash
#c2-client module
#AsrirGGxuI
#dir

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

dir_cd() {
    # přiřadí prázdnou hodnotu, pokud $1 není nastaveno
    local target="${1:-}"

    # pokud není parametr zadán, nic nedělej
    [[ -z "$target" ]] && return 0

    case "$target" in
    ..|/..)
        # Jdi o adresář výš
        CURRENT_DIR=$(dirname "$CURRENT_DIR")
        ;;
    .|/.)
        # Zůstaň ve stejném adresáři – nic nedělej
        ;;
    /*)
        # Absolutní cesta
        CURRENT_DIR="$target"
        ;;
    *)
        # Relativní cesta
        CURRENT_DIR="$CURRENT_DIR/$target"
        ;;
esac
}

dir_pwd() {
 echo "$CURRENT_DIR"
}

# Wrapper funkce
dir_wrapper() {
    local cmd="$*"
    echo "cd $CURRENT_DIR && $cmd"
}

AsrirGGxuI_init() {
    register_function "cd" "dir_cd" 1 "change directory"
    register_function "pwd" "dir_pwd" 0 "print working directory"
}

AsrirGGxuI_main() {
    CURRENT_DIR=$(send_cmd "pwd")
    register_cmd_wrapper dir_wrapper 999
    print_std "Directory wrapper initialized. Starting in $CURRENT_DIR"
}

AsrirGGxuI_description() {
    echo "Maintains virtual working directory across commands"
}

AsrirGGxuI_help() {
    :
}

