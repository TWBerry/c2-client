#!/usr/bin/env bash
#c2-client module
#eFSiTjxlkn
#transfer

source funcmgr.sh
PROGRESS_WIDTH=25
eFSiTjxlkn_init() {
  register_function "download" "parallel_download" 7 "Download a file"
  register_function "upload" "parallel_upload" 7 "Upload a file"
  register_function "emergency_upload" "emergency_upload" 3 "Emergency upload for non-binary files"
}

eFSiTjxlkn_description() {
  echo "File Upload/Download module"
}

eFSiTjxlkn_help() {
  echo -e "${BLUE}download ${NC}<remote> [-c chunk_size] [-o local] [-t threads]"
  echo -e "${BLUE}upload ${NC}<local> [-c chunk_size] [-o remote] [-t threads]"
  echo -e "${BLUE}emergency_upload ${NC}<local> [-o remote]"
}

emergency_upload() {
  local local_file="$1"
  local remote_file="$local_file"

  if [ -z "$local_file" ] || [ -z "$remote_file" ]; then
    echo "Usage: emergency_upload <local_file> [-o remote_file]"
    return 1
  fi
  shift
  while getopts "o:" opt; do
    case $opt in
      o)
        remote_file="$OPTARG"
        ;;
      \?)
        echo "${RED}[+]${NC}Unknown parameter: -$OPTARG" >&2
        return 1
        ;;
      :)
        echo "${RED}[+]${NC}Bad value for -$OPTARG" >&2
        return 1
        ;;
    esac
  done
  # clear remote file first
  send_cmd "echo -n '' > $remote_file"
  local lineno=0
  while IFS= read -r line; do
    lineno=$((lineno + 1))
    # escape quotes to avoid breaking echo
    safe_line=$(printf "%s" "$line" | sed "s/'/'\"'\"'/g")
    send_cmd "echo '$safe_line' >> $remote_file"
    echo -e "${GREEN}[*]${NC} Sent line $lineno"
  done <"$local_file"

  echo -e "${GREEN}[+]${NC} Upload complete -> $remote_file"
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
  local LOCAL_FILE="$1"
  local REMOTE_OUT="$1"
  local THREADS=8
  local CHUNK_SIZE=512
  local REMOTE_B64="upload.b64"
  local PART_PREFIX="part_"
  shift
  while getopts "c:o:t:" opt; do
    case $opt in
      c)
        CHUNK_SIZE="$OPTARG"
        ;;
      o)
        REMOTE_OUT="$OPTARG"
        ;;
      t)
        THREADS="$OPTARG"
        ;;
      \?)
        echo "${RED}[+]${NC} Unknown parameter: -$OPTARG" >&2
        return 1
        ;;
      :)
        echo "${RED}[+]${NC} Bad value for -$OPTARG" >&2
        return 1
        ;;
    esac
  done

  [[ ! -f "$LOCAL_FILE" ]] && {
    echo -e "${RED}[!]${NC} Local file not found"
    return 1
  }

  # Příprava base64
  B64TMP="$(mktemp)"
  $LOCAL_B64_ENCODE_CMD "$LOCAL_FILE" | tr -d '\n' >"$B64TMP"

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
  send_cmd "$BASE64_DECODE_CMD ${REMOTE_B64}.parts > '$REMOTE_OUT' && rm ${REMOTE_B64}.parts"

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
  local remote_md5=$(send_cmd "md5sum '$REMOTE_OUT' | awk '{print \$1}'")
  local local_md5=$(md5sum "$LOCAL_FILE" | awk '{print $1}')

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
  local REMOTE_FILE="$1"
  local LOCAL_OUT="$1"
  local THREADS=8
  local CHUNK_SIZE=512
  local TMP_DIR="$(mktemp -d)"
  local PART_PREFIX="${TMP_DIR}/part_"
  shift

  while getopts "c:o:t:" opt; do
    case $opt in
      c)
        CHUNK_SIZE="$OPTARG"
        ;;
      o)
        LOCAL_OUT="$OPTARG"
        ;;
      t)
        THREADS="$OPTARG"
        ;;
      \?)
        echo "${RED}[+] ${NC}Unknown parameter: -$OPTARG" >&2
        return 1
        ;;
      :)
        echo "${RED}[+] ${NC}Bad value for -$OPTARG" >&2
        return 1
        ;;
    esac
  done

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

    CMD="dd if='$REMOTE_FILE' bs=1 skip=$offset count=$count 2>/dev/null | $BASE64_ENCODE_CMD"
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
  $LOCAL_B64_DECODE_CMD "${TMP_DIR}/full.b64" >"$LOCAL_OUT"

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

eFSiTjxlkn_main() {
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
      echo "$${RED}[+] ${NC}Remote base64 dezection error"
      exit 1
      ;;
  esac

  if [[ "$HELPER" == "xxd_od" ]]; then
    LOCAL_B64_DECODE_CMD="$BASE64_DECODE_CMD"
    LOCAL_B64_ENCODE_CMD="$BASE64_ENCODE_CMD"
  else
    LOCAL_B64_DECODE_CMD="base64 -d"
    LOCAL_B64_ENCODE_CMD="base64 -w0"
  fi

  if [[ -z "$HELPER" ]]; then
    echo -e "${GREEN}[+] ${NC} Found base64 on remote system no helper is needed..."
  else
    echo -e "${GREEN}[+] ${NC} Found $B64_INTERPRETER uploading $HELPER by emergency upload...."
    emergency_upload "./helpers/$HELPER" "-o" "$HELPER"
    send_cmd "chmod +x $HELPER"
  fi
}
