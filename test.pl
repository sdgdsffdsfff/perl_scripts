#!/usr/bin/perl
use warnings;
use diagnostics;
use strict;
use 5.010;
use Thread;
use Term::Cap;
use POSIX;


my $termios = new POSIX::Termios;
$termios->getattr(1);
my $ospeed = $termios->getospeed;
my $col = 0;
my $row = 0;
#An optional filehandle (or IO::Handle ) that output will be printed to.
my $FH = *STDOUT;
my $terminal = Tgetent Term::Cap { TERM => undef, OSPEED => $ospeed };
$terminal->Trequire(qw/ce ku kd/);
#Tgoto decodes a cursor addressing string with the given parameters
#clear the screen
my $clear_string = $terminal->Tputs('cl');
print $clear_string;

while (1){
	$terminal->Tgoto('cm', $col, $row, $FH);
	my $time = `date`;
	print "$time";
	sleep 1;	
}


