#!/usr/bin/env php
<?php
//  php b64helper.php encode < infile > outfile.b64
//  php b64helper.php decode < infile.b64 > outfile
$cmd = $argv[1] ?? '';
if ($cmd === 'encode') {
    $data = fopen('php://stdin','r');
    $buf = '';
    while (!feof($data)) $buf .= fgets($data, 8192);
    echo rtrim(base64_encode($buf), "\n");
} elseif ($cmd === 'decode') {
    $in = stream_get_contents(STDIN);
    $decoded = base64_decode($in, true);
    if ($decoded === false) { fwrite(STDERR, "Bad base64\n"); exit(2); }
    echo $decoded;
} else {
    fwrite(STDERR, "Usage: php b64helper.php encode|decode\n");
    exit(1);
}
