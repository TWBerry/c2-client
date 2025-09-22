#!/usr/bin/env php
<?php
posix_setuid(0);

$cmd = implode(' ', array_slice($argv, 1));
system($cmd);
?>
