#!/usr/bin/env bash
#c2-client module
#uONYoUDBwv
#tor
source funcmgr.sh

uONYoUDBwv_init() {
  register_function "enable_tor" "enable_tor" "0" 'Enable tor socks proxy'
  register_function "disable_tor" "disable_tor" "0" 'Disable tor socks proxy'
  register_function "show_ip" "show_ip" "0" "Show public IP"
  register_function "change_ip" "change_ip" "2" "Request new Tor identity"
  register_cmdline_param "--no-tor" "disable_tor_startup" "enable_tor_startup"
}

disable_tor_startup() {
  unset ALL_PROXY 2>/dev/null || true
  echo -e "${YELLOW}[!]${NC} Tor proxy disabled at startup"
}

enable_tor_startup() {
  export ALL_PROXY="socks5://127.0.0.1:9050"
  echo -e "${GREEN}[+]${NC} Tor proxy enabled at startup (use --no-tor to disable)"
}

uONYoUDBwv_main() {
  :
}

uONYoUDBwv_description() {
  echo "Tor module with command-line control"
}

uONYoUDBwv_help() {
  echo -e "${BLUE}enable_tor${NC} enable tor socks proxy"
  echo -e "${BLUE}disable_tor${NC} disable tor socks proxy"
  echo -e "${BLUE}show_ip${NC} show public ip (uses Tor proxy if enabled)"
  echo -e "${BLUE}change_ip${NC} change Tor exit IP (options: -c cookie_path | -p password)"
  echo -e "${BLUE}--no-tor${NC} command-line argument to disable Tor proxy at startup"
}

enable_tor() {
  export ALL_PROXY="socks5://127.0.0.1:9050"
  echo -e "${GREEN}[*] ${YELLOW}Tor proxy enabled${NC}"
}

disable_tor() {
  unset ALL_PROXY
  echo -e "${GREEN}[*] ${YELLOW}Tor proxy disabled${NC}"
}

# helper: call curl via Tor if ALL_PROXY set, otherwise direct
_get_ip_via_tor_or_direct() {
  # prefer using socks proxy if ALL_PROXY is set to socks5://127.0.0.1:9050
  if [[ -n "${ALL_PROXY:-}" ]]; then
    curl -s --socks5-hostname 127.0.0.1:9050 --connect-timeout 10 https://ifconfig.me ||
      curl -s --socks5-hostname 127.0.0.1:9050 --connect-timeout 10 https://ipinfo.io/ip || true
  else
    curl -s --connect-timeout 10 https://ifconfig.me || curl -s --connect-timeout 10 https://ipinfo.io/ip || true
  fi
}

show_ip() {
  echo -e "${GREEN}[*] ${YELLOW}Checking public IP...${NC}"
  local ip
  ip="$(_get_ip_via_tor_or_direct)"
  if [[ -z "$ip" ]]; then
    echo -e "${RED}[!]${NC} Could not determine IP (curl failed)."
    return 1
  fi
  echo -e "${GREEN}[+]${NC} Public IP: ${BLUE}$ip${NC}"
  return 0
}

# helper: read control auth cookie and return hex string
_read_cookie_hex() {
  local cookie_file="$1"
  if [[ ! -r "$cookie_file" ]]; then
    return 2
  fi
  if command -v xxd >/dev/null 2>&1; then
    xxd -p "$cookie_file" | tr -d '\n'
  else
    # fallback to od
    od -An -tx1 "$cookie_file" | tr -d ' \n'
  fi
}

# change_ip: accepts -c cookie_path OR -p password
# usage: change_ip -c /run/tor/control.authcookie
#        change_ip -p 'my_password'
change_ip() {
  local OPT_C=""
  local OPT_P=""
  # parse options
  while getopts ":c:p:" opt; do
    case "$opt" in
      c) OPT_C="$OPTARG" ;;
      p) OPT_P="$OPTARG" ;;
      \?)
        echo "Invalid option: -$OPTARG" >&2
        return 3
        ;;
      :)
        echo "Option -$OPTARG requires an argument." >&2
        return 4
        ;;
    esac
  done
  shift $((OPTIND - 1))

  # control port host/port
  local CTRL_HOST="127.0.0.1"
  local CTRL_PORT="9051"

  if ! command -v nc >/dev/null 2>&1; then
    echo -e "${RED}[!]${NC} 'nc' (netcat) is required to talk to Tor ControlPort." >&2
    return 5
  fi

  # build auth/authenticate sequence
  local auth_line=""
  if [[ -n "$OPT_P" && -n "$OPT_C" ]]; then
    echo -e "${YELLOW}[!]${NC} Both -p and -c provided; using cookie (-c) preferentially."
  fi

  if [[ -n "$OPT_C" ]]; then
    # try provided cookie path, or fallback defaults if value is empty
    local cookie="$OPT_C"
    if [[ "$cookie" == "-" ]]; then
      # disallow '-' as special; just require explicit path
      echo -e "${RED}[!]${NC} Provide explicit cookie path with -c" >&2
      return 6
    fi
    if [[ ! -r "$cookie" ]]; then
      # try common locations if the argument looked like 'default'
      if [[ -r "/run/tor/control.authcookie" ]]; then
        cookie="/run/tor/control.authcookie"
      elif [[ -r "/var/run/tor/control.authcookie" ]]; then
        cookie="/var/run/tor/control.authcookie"
      else
        echo -e "${RED}[!]${NC} Cookie file not readable: $cookie" >&2
        return 7
      fi
    fi
    local cookie_hex
    cookie_hex=$(_read_cookie_hex "$cookie") || {
      echo -e "${RED}[!]${NC} Failed to read cookie or convert to hex"
      return 8
    }
    auth_line="AUTHENTICATE ${cookie_hex}\r\n"
  elif [[ -n "$OPT_P" ]]; then
    # password auth (quoted)
    # escape backslashes and double quotes in password
    local pw="${OPT_P//\\/\\\\}"
    pw="${pw//\"/\\\"}"
    auth_line="AUTHENTICATE \"${pw}\"\r\n"
  else
    # no auth provided: try cookie default locations
    if [[ -r "/run/tor/control.authcookie" ]]; then
      local cookie="/run/tor/control.authcookie"
      local cookie_hex
      cookie_hex=$(_read_cookie_hex "$cookie") || {
        echo -e "${RED}[!]${NC} Failed to read cookie or convert to hex"
        return 9
      }
      auth_line="AUTHENTICATE ${cookie_hex}\r\n"
    else
      echo -e "${RED}[!]${NC} No auth specified and no default cookie found. Use -c or -p." >&2
      return 10
    fi
  fi

  echo -e "${GREEN}[*]${NC} Requesting new Tor identity (SIGNAL NEWNYM) via ControlPort ${CTRL_HOST}:${CTRL_PORT}..."

  # send AUTH and NEWNYM
  # wrap in a small here-doc sent to nc
  {
    printf '%b' "${auth_line}"
    printf 'SIGNAL NEWNYM\r\nQUIT\r\n'
  } | nc "${CTRL_HOST}" "${CTRL_PORT}" -w 5 | {
    # read response
    IFS= read -r resp || true
    if [[ "$resp" =~ ^250 ]]; then
      echo -e "${GREEN}[+]${NC} Tor accepted NEWNYM command (response: $resp)"
    else
      echo -e "${YELLOW}[!]${NC} Tor ControlPort responded: $resp"
      # still continue to wait — sometimes ControlPort returns different messages but NEWNYM may still take effect
    fi
  }

  # wait until IP changes (max 60s)
  local old_ip
  old_ip="$(_get_ip_via_tor_or_direct)" || old_ip=""
  echo -e "${GREEN}[*]${NC} Old IP (via current proxy): ${BLUE}${old_ip:-unknown}${NC}"
  local waited=0
  local new_ip=""
  while ((waited < 60)); do
    sleep 3
    waited=$((waited + 3))
    new_ip="$(_get_ip_via_tor_or_direct)" || new_ip=""
    if [[ -n "$new_ip" && "$new_ip" != "$old_ip" ]]; then
      echo -e "${GREEN}[+]${NC} New IP: ${BLUE}$new_ip${NC}"
      return 0
    fi
  done

  echo -e "${YELLOW}[!]${NC} Timeout waiting for new Tor IP (tried 60s). Current IP: ${BLUE}${new_ip:-unknown}${NC}"
  return 11
}
