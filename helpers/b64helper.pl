#!/usr/bin/env perl
use strict;
use warnings;
use MIME::Base64;
my $cmd = shift @ARGV;
my $in = do { local $/; <STDIN> };
if ($cmd eq 'encode') {
    print encode_base64($in, '');
} elsif ($cmd eq 'decode') {
    my $out = eval { decode_base64($in) };
    if ($@) { print STDERR "Bad base64\n"; exit 2 }
    print $out;
} else {
    die "Usage: b64helper.pl encode|decode\n";
}
