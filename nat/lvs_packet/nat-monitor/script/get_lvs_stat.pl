#!/usr/bin/perl

use File::Basename;
$MAIN_DIR=dirname($0);
require ($MAIN_DIR."/lib/report.pl");
require ($MAIN_DIR."/conf/gconf.pl");

##################
# basic variables
##################
## my true and false
use constant true => 1;
use constant TRUE => 1;
use constant false => 0;
use constant FALSE =>0;

my $debug = false;
my $res;

################ SESSION STAT ###############
my $activeSession=0;
my $inactiveSession=0;
my $oldTime=0;
my $session_group="session";

sub computeSession($$) {
	my @tmpSession;
	if ($_[0] == 0) {
		@tmpSession = `/sbin/ipvsadm -ln | grep Masq | awk '{total += \$5; total2 += \$6;} END {print total+0; print total2+0;}' 2>/dev/null`;	
	} else {
		@tmpSession = `cat $_[1] | grep Masq | awk '{total += \$5;  total2 += \$6;} END {print total; print total2;}' 2>/dev/null`;	
	}

	if ($? == 0) {
		chomp($tmpSession[0]);
		chomp($tmpSession[1]);
		$activeSession = $tmpSession[0];
		$inactiveSession = $tmpSession[1];
	} else {
		return false;
	}

	return true;
}

my $timeDelta = 1;
if ($timeDelta != 0)
{ 
	my $ipvsadmRet=`/sbin/ipvsadm -ln 2>/dev/null 0</dev/null`;
	$res=computeSession(0, 0);
	if ($res == true) {
		if ($debug) {
			print "activeSession is $activeSession, and inactiveSession is $inactiveSession\n";
			print "delta time is $timeDelta\n";
		} else {
			system("$CLIENT -t uint32 -n active_session -v $activeSession -g $session_group 2>/dev/null");	
			system("$CLIENT -t uint32 -n inactive_session -v $inactiveSession -g $session_group 2>/dev/null");	
		}
	}
} 

################ IP_VS_CONN STAT ###############
$res = `cat /proc/slabinfo | grep ip_vs_conn | awk '{print \$3*\$4;}' 2>/dev/null`;

if ($debug)
{
	print "ip_vs_conn mem is $res";
} else {
	chomp($res);
	system("$CLIENT -t uint32 -n ip_vs_conn -v $res -g $session_group 2>/dev/null");	
}


