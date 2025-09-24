#!/usr/bin/env bash
#c2-client module
#MtJEHwUMnj
#script

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

# run_script <path-to-script>
# Safely source a script file written for the client.
run_script() {
    local script="$1"
    if [[ -z "${script:-}" ]]; then
        print_err "run_script: missing script path"
        return 2
    fi
    if [[ ! -f "$script" || ! -r "$script" ]]; then
        print_err "run_script: script not found or not readable: $script"
        return 3
    fi
    # wrapper function - executes script in function scope so variables are local
    __run_script_inner() {
       (
        # make script errors propagate as return code of this function
        set -o errexit -o pipefail

        # Protect client from script calling destructive shell builtins:
        exit()   { return "${1:-0}"; }    # exit n -> return n
        exec()   { print_err "script attempted exec - blocked"; return 1; }
        eval()   { print_err "script attempted eval - blocked"; return 1; }
        logout() { return 0; }

        # Optional helper for controlled failure
        fail() { print_err "script failed: $*"; return 1; }

        # Source the script into this function scope (so its variables are local)
        # shellcheck disable=SC1090
        source "$script"
       )
    }

    # Call the wrapper and capture status
    print_dbg "[SCRIPT STARTED]"
    __run_script_inner
    local rc=$?

    if [[ $rc -ne 0 ]]; then
        print_err "run_script: script exited with status $rc ($script)"
    else
        print_std "run_script: completed $script"
    fi
   print_dbg "[SCRIPT ENDED - return code: $rc]"
    return $rc
}


MtJEHwUMnj_init() {
    register_function "run_script" "run_script" 1 "Run user script"
}

MtJEHwUMnj_main() {
    :
}

MtJEHwUMnj_description() {
    echo "Base support for scripting"
}

MtJEHwUMnj_help() {
    print_help "run_script" "<script_ name> run a c2 script"
}

