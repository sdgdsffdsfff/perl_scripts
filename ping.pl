#!/usr/bin/perl
use warnings;
use utf8;
use diagnostics;
use strict;
use 5.010;
use threads;

sub my_ping{
	my $ip = @_;
	say $ip;
	my $string = 'ping -c 1 '.$ip;
	say $string;
	my $info = system($string);
	#my $info = `ping -c 1 114.114.114.114`;
	say $info;
}

my $t1 = threads->create("my_ping","'114.114.114.114'");
$t1->join();

