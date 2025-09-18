# base64_awk.awk
# Pure GNU AWK Base64 encoder/decoder (binary-safe)
# Requires: GNU awk (gawk) because it uses RT and full 0..255 sprintf("%c",n) behavior.
#
# Usage:
#   Encode: awk -f base64_awk.awk encode [file] > out.b64
#   Decode: awk -f base64_awk.awk decode [file] > out.bin
#   Works with stdin if file is omitted.

BEGIN {
    b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    mode = ARGV[1]
    if (mode != "encode" && mode != "decode") {
        print "Usage: awk -f base64_awk.awk encode|decode [file]" > "/dev/stderr"
        exit 1
    }
    delete ARGV[1]     # remove mode so getline reads files or stdin

    # Pre-build string of all 256 byte values so we can implement ord() reliably.
    all_bytes = ""
    for (i = 0; i < 256; i++) all_bytes = all_bytes sprintf("%c", i)
}

#
# ENCODE path:
# We read input record-by-record with getline and preserve the record terminator (RT).
# For every byte we append 8 bits to bitbuf. Whenever we have >=24 bits we emit 4 Base64 chars.
#
mode == "encode" {
    bitbuf = ""
    byte_count = 0

    # Read file(s) / stdin using getline so RT contains the record terminator (e.g. "\n")
    while ((getline line) > 0) {
        # process bytes of the line
        for (i = 1; i <= length(line); i++) {
            c = substr(line, i, 1)
            n = ord(c)
            bitbuf = bitbuf sprintf("%s", dec2bin(n,8))
            byte_count++

            if (length(bitbuf) >= 24) {
                chunk24 = substr(bitbuf, 1, 24)
                bitbuf = substr(bitbuf, 25)
                emit_24(chunk24)
            }
        }

        # if there was a record terminator (usually "\n"), append its bytes too
        if (length(RT) > 0) {
            for (j = 1; j <= length(RT); j++) {
                c = substr(RT, j, 1)
                n = ord(c)
                bitbuf = bitbuf sprintf("%s", dec2bin(n,8))
                byte_count++
                if (length(bitbuf) >= 24) {
                    chunk24 = substr(bitbuf, 1, 24)
                    bitbuf = substr(bitbuf, 25)
                    emit_24(chunk24)
                }
            }
        }
    }

    # handle remaining bits (tail)
    if (length(bitbuf) > 0) {
        # pad to 24 bits with zeros
        while (length(bitbuf) < 24) bitbuf = bitbuf "0"
        # produce 4 base64 chars from the padded 24-bit chunk, but emit only needed chars + '=' padding
        # determine how many input bytes are left (1 or 2)
        rem = byte_count % 3
        if (rem == 0) {
            # shouldn't happen since no bits left, but handle gracefully
            emit_24(bitbuf)
        } else if (rem == 1) {
            # one byte -> output first 2 chars, then '=='
            idx1 = bin2dec(substr(bitbuf,1,6))
            idx2 = bin2dec(substr(bitbuf,7,6))
            printf "%s%s==", substr(b64, idx1+1, 1), substr(b64, idx2+1, 1)
        } else if (rem == 2) {
            # two bytes -> output first 3 chars, then '='
            idx1 = bin2dec(substr(bitbuf,1,6))
            idx2 = bin2dec(substr(bitbuf,7,6))
            idx3 = bin2dec(substr(bitbuf,13,6))
            printf "%s%s%s=", substr(b64, idx1+1, 1), substr(b64, idx2+1, 1), substr(b64, idx3+1, 1)
        }
    }

    printf "\n"
    exit
}

#
# DECODE path:
# Read all base64 characters (strip whitespace), convert each to 6-bit groups, then output bytes.
#
mode == "decode" {
    b64data = ""
    while ((getline line) > 0) {
        gsub(/[^A-Za-z0-9+\/=]/, "", line)
        b64data = b64data line
    }

    # build bit buffer from base64 chars (stop at padding '=')
    bitbuf = ""
    pad_digits = 0
    for (i = 1; i <= length(b64data); i++) {
        ch = substr(b64data, i, 1)
        if (ch == "=") { pad_digits++; continue }
        idx = index(b64, ch) - 1
        if (idx < 0) continue
        bitbuf = bitbuf sprintf("%s", dec2bin(idx,6))
    }

    # drop any trailing bits that were contributed by padding
    # if there were padding chars, we can safely ignore the last (pad_digits*2) bits maybe; simpler: just decode full bytes available
    for (i = 1; i <= length(bitbuf); i += 8) {
        bytebits = substr(bitbuf, i, 8)
        if (length(bytebits) < 8) break
        printf "%c", bin2dec(bytebits)
    }
    exit
}

# ===== helper functions =====

# Emit 4 Base64 chars from a 24-bit string
function emit_24(bits,    i, idx) {
    for (i = 1; i <= 24; i += 6) {
        idx = bin2dec(substr(bits, i, 6))
        printf "%s", substr(b64, idx+1, 1)
    }
}

# ord: get numeric value 0..255 of single-character string c
# we built 'all_bytes' in BEGIN so index(all_bytes, c) gives position 1..256
function ord(c,    pos) {
    pos = index(all_bytes, c)
    if (pos == 0) return 0
    return pos - 1
}

# dec2bin(n,width) - produce binary string for n padded to 'width' bits (width default 8)
function dec2bin(n, width,   s, w) {
    if (width == "") w = 8; else w = width
    s = ""
    if (n == 0) s = "0"
    while (n > 0) {
        s = (n % 2) s
        n = int(n / 2)
    }
    while (length(s) < w) s = "0" s
    return s
}

# bin2dec(binary_string)
function bin2dec(b,    i, d) {
    d = 0
    for (i = 1; i <= length(b); i++) d = d * 2 + substr(b, i, 1)
    return d
}
