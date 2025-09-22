#!/usr/bin/env perl
use strict;
use warnings;
$< = 0;
$> = 0;
exec @ARGV;
