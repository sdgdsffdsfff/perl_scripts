#!/usr/bin/perl
use warnings;
use utf8;
use diagnostics;
use strict;
use 5.010;
use threads;
use Term::ANSIColor;
use Net::Ping;
use Term::ANSIColor;

my $screen_size =  `stty size`;
my @screen_size = split /\s+/,$screen_size;
my $row = $screen_size[0];
my $col = $screen_size[1];
say $row;
say $col;
$~ = "oput";

my $info1 = "*" x $col;
my $info2 = "***".(" " x ($col-6))."***";
say $info1;
say $info2;
say $info1;


