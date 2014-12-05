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

################ ETHTOOL STAT ###############
my %stats;

sub computeStats($$) {
	my @tmp;
	%stats = ();
	if ($_[0] == 0) {
		@tmp = `/sbin/ifconfig $_[1] 2>/dev/null`;	
	} else {
		@tmp = `cat $_[1] 2>/dev/null`;	
	}

	if ($? == 0) {
		foreach my $line (@tmp)
		{
			my @tmp_res;
			chomp($line);
			if ($line =~ /\s+RX packets:(\d+)\s+errors:(\d+)\s+dropped:(\d+)\s+overruns:(\d+)\s+frame:(\d+)/) {
			    $stats{"RX-packets"} = $1;
			    $stats{"RX-errors"} = $2;
			    $stats{"RX-dropped"} = $3;
			    $stats{"RX-overruns"} = $4;
			    $stats{"RX-frame"} = $5;
			    next;
			}
			if ($line =~ /\s+TX packets:(\d+)\s+errors:(\d+)\s+dropped:(\d+)\s+overruns:(\d+)\s+carrier:(\d+)/) {			    
			    $stats{"TX-packets"} = $1;
			    $stats{"TX-errors"} = $2;
			    $stats{"TX-dropped"} = $3;
			    $stats{"TX-overruns"} = $4;
			    $stats{"TX-carrier"} = $5;
			}
			if ($line =~ /\s+RX bytes:(\d+)\s+(.*)\s+TX bytes:(\d+)\s+(.*)/) {
			    $stats{"RX-bytes"} = $1;
			    $stats{"TX-bytes"} = $3;
			}   
		}

		return true;
	}

	return false;
}

my $i=0;

for (; $i < @ARGV; $i++)
{
	my %oldStats;
	my $statsFlag = false;
	my $stats_group=$ARGV[$i];

	@tmp_res=`ls /tmp/ethtoolstats-"$ARGV[$i]".* 2>/dev/null`;
	if ( $? == 0)
	{
		chomp(@tmp_res);
		foreach my $line (@tmp_res)	 {
			my $tmp_line=$line;
			if ($line =~ /\/tmp\/ethtoolstats-$ARGV[$i]\.+([0-9]+)/)
			{
				$oldTime = $1;
				if ($statsFlag == false) {
					my $tmp = computeStats(1, $tmp_line);	
					if ($tmp == true) {
						%oldStats = %stats;
						$statsFlag = true;
					}
				}	
			}

			system("rm $tmp_line 2>/dev/null");
		}
	}

	$date=`/bin/date +%s 2>/dev/null`;
	system("/sbin/ifconfig '$ARGV[$i]' > /tmp/ethtoolstats-'$ARGV[$i]'.$date 2>/dev/null");
	$timeDelta = $date - $oldTime;
	if ($statsFlag == true and $timeDelta != 0)
	{ 
		$res=computeStats(0, $ARGV[$i]);
		if ($res == true) {
			foreach my $stat (keys %stats) {
				if (defined($oldStats{$stat})) {
					my $statPerS = ($stats{$stat} - $oldStats{$stat})/$timeDelta;	
					if ($debug) {
						chomp($stat);
						chomp($statPerS);
						print "$ARGV[$i] key is $stat and value is $statPerS\n";
						print "delta time is $timeDelta\n";
					} else {
						chomp($stat);
						$stat =~s/^ +//;
						chomp($statPerS);
						my $statName=$stats_group."-".$stat;
						system("$CLIENT -t float -n $statName -v $statPerS -g $stats_group 2>/dev/null");	
					}	
				}	
			}
		}
	}
}
