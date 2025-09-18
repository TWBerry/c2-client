#!/usr/bin/env bash
set -euo pipefail

# Configuration
MODULES_LIST="./modules"  # soubor se seznamem modulů (jméno každého modulu na řádek)
MODULES_DIR="./modules.d" # defaultní složka pro nové moduly (změň si dle potřeby)

mkdir -p "$(dirname "$MODULES_LIST")"
mkdir -p "$MODULES_DIR"

# create a new module file
# usage: make_new_module <module_name> [output_path]
make_new_module() {
  local name="$1"
  local out="${2:-${MODULES_DIR}/${name}.sh}"

  # safe check: do not overwrite existing file unless asked
  if [[ -e "$out" ]]; then
    echo "Error: target file already exists: $out" >&2
    return 1
  fi

  # generate ID (10 case-mixed letters)
  local ID
  ID=$(LC_ALL=C tr -dc 'A-Za-z' </dev/urandom | head -c 10 || true)

  echo "#!/usr/bin/env bash" >>"$out"
  echo "#c2-client module" >>"$out"
  echo "#$ID" >>"$out"
  echo "#$name" >>"$out"
  echo "" >>"$out"
  echo "source funcmgr.sh" >>"$out"
  echo "${ID}_init() {" >>"$out"
  echo "    :" >>"$out"
  echo "}" >>"$out"
  echo "" >>"$out"
  echo "${ID}_main() {" >>"$out"
  echo "    :" >>"$out"
  echo "}" >>"$out"
  echo "" >>"$out"
  echo "${ID}_description() {" >>"$out"
  echo "    :" >>"$out"
  echo "}" >>"$out"
  echo "" >>"$out"
  echo "${ID}_help() {" >>"$out"
  echo "    :" >>"$out"
  echo "}" >>"$out"

  chmod +x "$out"
  echo "Module '$name' was created at: $out"
}

# register module name in MODULES_LIST (no duplicates)
# usage: register_module <module_name>
register_module() {
  local name="$1"
  if grep -E -n "send_cmd\(\)" "modules.d/$name.sh" >/dev/null 2>&1; then
    echo "Error: Cannot register module '${name}' — contains 'send_cmd'. Shell modules cannot be registered."
    return 1
  fi
  # create file if missing
  touch "$MODULES_LIST"
  if LC_ALL=C grep -Fxq -- "$name" "$MODULES_LIST"; then
    echo "Module '$name' is already registered."
    return 0
  fi
  echo "$name" >>"$MODULES_LIST"
  echo "Module '$name' was registered."
}

# unregister module (remove all exact matches)
# usage: unregister_module <module_name>
unregister_module() {
  local name="$1"
  if [[ ! -f "$MODULES_LIST" ]]; then
    echo "Modules list not found: $MODULES_LIST" >&2
    return 1
  fi
  local tmp
  tmp="$(mktemp)" || {
    echo "Failed to create temp file" >&2
    return 1
  }
  trap 'rm -f "$tmp"' RETURN
  LC_ALL=C grep -Fxv -- "$name" "$MODULES_LIST" >"$tmp" || true
  mv -- "$tmp" "$MODULES_LIST"
  trap - RETURN
  echo "Module '$name' was unregistered."
}

print_usage() {
  cat <<USG
Usage: $0 <command> <module_name> [output_path]

Commands:
  new <module_name> [output_path]      Create a new module file (default dir: $MODULES_DIR)
  register <module_name>               Add module name to $MODULES_LIST (no duplicates)
  unregister <module_name>             Remove module name from $MODULES_LIST
  list
  help                                 Show this help
USG
}

# list all modules (registered + files)
list_modules() {
  echo "=== Registered modules (from $MODULES_LIST) ==="
  if [[ -s "$MODULES_LIST" ]]; then
    nl -w2 -s'. ' "$MODULES_LIST"
  else
    echo "(none registered)"
  fi
  echo

  echo "=== Existing module files (from $MODULES_DIR) ==="
  if compgen -G "${MODULES_DIR}/*.sh" >/dev/null; then
    for f in "$MODULES_DIR"/*.sh; do
      echo " - $(basename "$f")"
    done
  else
    echo "(no module files found)"
  fi
}

# ---- main dispatch ----
if [[ "${1:-}" == "" ]]; then
  print_usage
  exit 1
fi

cmd="$1"
shift || true

case "$cmd" in
  create)
    if [[ -z "${1:-}" ]]; then
      echo "Missing module name" >&2
      print_usage
      exit 1
    fi
    make_new_module "$1" "${2:-}"
    ;;
  register)
    if [[ -z "${1:-}" ]]; then
      echo "Missing module name" >&2
      print_usage
      exit 1
    fi
    register_module "$1"
    ;;
  unregister)
    if [[ -z "${1:-}" ]]; then
      echo "Missing module name" >&2
      print_usage
      exit 1
    fi
    unregister_module "$1"
    ;;
  help | -h | --help)
    print_usage
    ;;
  list)
    list_modules
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    print_usage
    exit 1
    ;;
esac
