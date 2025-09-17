#!/usr/bin/env php
<?php
if ($argc != 2) {
    fwrite(STDERR, "Usage: {$argv[0]} <file>\n");
    exit(1);
}
$file = $argv[1];
if (!file_exists($file)) {
    fwrite(STDERR, "File not found: $file\n");
    exit(1);
}
$hash = md5_file($file);
echo $hash . "  " . $file . PHP_EOL;
?>
