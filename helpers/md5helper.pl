#!/usr/bin/env perl
use strict;
use warnings;
use Digest::MD5;

my $file = shift or die "Usage: $0 <file>\n";
open my $fh, '<', $file or die "File not found\n";
binmode($fh);
my $md5 = Digest::MD5->new->addfile($fh)->hexdigest;
close $fh;
print "$md5  $file\n";
