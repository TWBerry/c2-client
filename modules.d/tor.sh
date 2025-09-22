#!/usr/bin/env bash
#c2-client module
#uONYoUDBwv
#tor
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

uONYoUDBwv_init() {
  register_function "enable_tor" "enable_tor" "0" 'Enable tor socks proxy'
  register_function "disable_tor" "disable_tor" "0" 'Disable tor socks proxy'
  register_function "show_ip" "show_ip" "0" "Show public IP"
  register_function "change_ip" "change_ip" "2" "Request new Tor identity"
  register_cmdline_param "--no-tor" "disable_tor_startup" "enable_tor_startup"
}

disable_tor_startup() {
  unset ALL_PROXY 2>/dev/null || true
  print_warn "Tor proxy disabled at startup"
}

enable_tor_startup() {
  export ALL_PROXY="socks5://127.0.0.1:9050"
  print_std "Tor proxy enabled at startup (use --no-tor to disable)"
}

uONYoUDBwv_main() {
  :
}

uONYoUDBwv_description() {
  echo "Tor module with command-line control"
}

uONYoUDBwv_help() {
  print_help "enable_tor" "enable tor socks proxy"
  print_help "disable_tor" "disable tor socks proxy"
  print_help "show_ip" "show public ip (uses Tor proxy if enabled)"
  print_help "change_ip" "change Tor exit IP (options: -c cookie_path | -p password)"
  print_help "--no-tor" "command-line argument to disable Tor proxy at startup"
}

enable_tor() {
  export ALL_PROXY="socks5://127.0.0.1:9050"
  print_out "Tor proxy enabled${NC}"
}

disable_tor() {
  unset ALL_PROXY
  print_out "Tor proxy disabled${NC}"
}

# helper: call curl via Tor if ALL_PROXY set, otherwise direct
# helper: call curl via Tor if ALL_PROXY set, otherwise direct
_get_ip_via_tor_or_direct() {
  local candidates=(
    "https://ifconfig.me"
    "https://ipinfo.io/ip"
    "https://api.ipify.org"
    "https://checkip.amazonaws.com"
  )
  local ip

  for url in "${candidates[@]}"; do
    ip=$(curl -s --connect-timeout 10 "$url" || true)

    # ořízni whitespace
    ip=$(echo "$ip" | tr -d '[:space:]')

    # validace IPv4 / IPv6 regexem
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ || "$ip" =~ ^([0-9a-fA-F:]+:+)+[0-9a-fA-F]+$ ]]; then
      echo "$ip"
      return 0
    fi
  done

  # když žádný neprojde
  return 1
}

show_ip() {
  print_out "Checking public IP..."
  local ip
  ip="$(_get_ip_via_tor_or_direct)"
  if [[ -z "$ip" ]]; then
    print_err "Could not determine IP (curl failed)."
    return 1
  fi
  print_std "Public IP: ${BLUE}$ip${NC}"
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
        print_err "Invalid option: -$OPTARG" >&2
        return 3
        ;;
      :)
        print_err "Option -$OPTARG requires an argument." >&2
        return 4
        ;;
    esac
  done
  shift $((OPTIND - 1))

  # control port host/port
  local CTRL_HOST="127.0.0.1"
  local CTRL_PORT="9051"

  if ! command -v nc >/dev/null 2>&1; then
    print_err "'nc' (netcat) is required to talk to Tor ControlPort." >&2
    return 5
  fi

  # build auth/authenticate sequence
  local auth_line=""
  if [[ -n "$OPT_P" && -n "$OPT_C" ]]; then
    print_warn "Both -p and -c provided; using cookie (-c) preferentially."
  fi

  if [[ -n "$OPT_C" ]]; then
    # try provided cookie path, or fallback defaults if value is empty
    local cookie="$OPT_C"
    if [[ "$cookie" == "-" ]]; then
      # disallow '-' as special; just require explicit path
      print_err "Provide explicit cookie path with -c"
      return 6
    fi
    if [[ ! -r "$cookie" ]]; then
      # try common locations if the argument looked like 'default'
      if [[ -r "/run/tor/control.authcookie" ]]; then
        cookie="/run/tor/control.authcookie"
      elif [[ -r "/var/run/tor/control.authcookie" ]]; then
        cookie="/var/run/tor/control.authcookie"
      else
        print_err "Cookie file not readable: $cookie"
        return 7
      fi
    fi
    local cookie_hex
    cookie_hex=$(_read_cookie_hex "$cookie") || {
      print_err "Failed to read cookie or convert to hex"
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
        print_err "Failed to read cookie or convert to hex"
        return 9
      }
      auth_line="AUTHENTICATE ${cookie_hex}\r\n"
    else
      print_err "No auth specified and no default cookie found. Use -c or -p." >&2
      return 10
    fi
  fi

  print_std "Requesting new Tor identity (SIGNAL NEWNYM) via ControlPort ${CTRL_HOST}:${CTRL_PORT}..."

  # send AUTH and NEWNYM
  # wrap in a small here-doc sent to nc
  {
    printf '%b' "${auth_line}"
    printf 'SIGNAL NEWNYM\r\nQUIT\r\n'
  } | nc "${CTRL_HOST}" "${CTRL_PORT}" -w 5 | {
    # read response
    IFS= read -r resp || true
    if [[ "$resp" =~ ^250 ]]; then
      print_std "Tor accepted NEWNYM command response: $resp"
    else
      print_warn "Tor ControlPort responded: $resp"
      # still continue to wait — sometimes ControlPort returns different messages but NEWNYM may still take effect
    fi
  }

  # wait until IP changes (max 60s)
  local old_ip
  old_ip="$(_get_ip_via_tor_or_direct)" || old_ip=""
  print_std "Old IP (via current proxy): ${BLUE}${old_ip:-unknown}${NC}"
  local waited=0
  local new_ip=""
  while ((waited < 60)); do
    sleep 3
    waited=$((waited + 3))
    new_ip="$(_get_ip_via_tor_or_direct)" || new_ip=""
    if [[ -n "$new_ip" && "$new_ip" != "$old_ip" ]]; then
      print_std "New IP: ${BLUE}$new_ip${NC}"
      return 0
    fi
  done

  print_warn "Timeout waiting for new Tor IP (tried 60s). Current IP: ${BLUE}${new_ip:-unknown}${NC}"
  return 11
}
