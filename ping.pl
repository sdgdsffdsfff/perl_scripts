#!/usr/bin/perl
use warnings;
use utf8;
use diagnostics;
use strict;
use 5.010;
use threads;
use threads::shared;
use Term::ANSIColor;
use Term::Cap;
use POSIX;
#--------------------------------------------------------------------------------------------
#init global variables
#--------------------------------------------------------------------------------------------
my %ping_result : shared;
my @thread_list;
my @ip_pools = qw{
	114.114.114.114
	119.75.217.56
	8.8.8.8
	123.125.82.241
};
#get screen parameters
my $screen_size =  `stty size`;
my @screen_size = split /\s+/,$screen_size;
my $screen_row = $screen_size[0];
my $screen_col = $screen_size[1];
#init the hash 
foreach(@ip_pools){
	$ping_result{$_} = "timeout";
}
#init terminal parameters
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

#--------------------------------------------------------------------------------------------
#init global variables
#--------------------------------------------------------------------------------------------
sub my_ping{
	my @ip =  @_;
	my $ip_addr = join ".",@ip;
	while(1){
		my $info = `ping -c 1 -w 3 $ip_addr`;
		if($info =~ /(?<time>time=.* ms)/){
			$ping_result{$ip_addr} = $+{time};
		}else{
			$ping_result{$ip_addr} = "timeout";
		}
		sleep 1;
	}
}
#--------------------------------------------------------------------------------------------
#start the main
#--------------------------------------------------------------------------------------------
#create threads 
foreach(@ip_pools){
	my $t = threads->create("my_ping",$_);
	push(@thread_list,$t);
}
#detach the threads
foreach(@thread_list){
	$_->detach();
}
#clear the screen
print $clear_string;
#loop for refreshing the screen
while (1){
	my $key;
	my $value;
	print $clear_string;
	my $info1 = "-" x $screen_col;
	my $info2 = "|".(" " x ($screen_col-2))."|";
	$terminal->Tgoto('cm', $col, $row, $FH);
	say $info1;
	say $info2;
	say $info1;
	while(($key,$value) = each %ping_result){
		if($value eq "timeout"){
			print color('bold red');
            		#print "$key => $value\n";
            		printf "%-15s => %-12s\n",$key,$value;
            		print color('reset');
            	}else{
            		#print "$key => $value\n";
            		printf "%-15s => %-15s\n",$key,$value;
            	}
	}
	sleep 1;	
}


