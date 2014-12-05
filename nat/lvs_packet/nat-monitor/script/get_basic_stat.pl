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

################ CPU STAT ###############
my $cpu_idle = 0.5; 
my $cpu_data = 0;

sub check_cpu_idle($)
{
	do
	{
		my $chkcmd = "LC_ALL=C /usr/bin/mpstat -P ALL 1 1";
		my @res = `$chkcmd 2>/dev/null 0</dev/null`;
		if( $? == 0 ) 
		{
			chomp(@res);
			my $flagmatch = 0;
			foreach my $line (@res)
			{
			 	######################### cpu_id  user nice  sys iowait irq soft steal idle interrupt ############       
				if ($line =~ /Average:\s+([0-9]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)/)
				{
					my $cpu_id = $1;
					my $cpu_group="CPU";

					my $user = $2;
					my $system = $4;
					my $iowait = $5;
					my $irq = $6;
					my $soft = $7;
					my $on_idle = $9;
					my $interrupt = $10;

					if ($debug) {
						print "cpu ".$cpu_id." system=".$system." iowait=".$iowait." soft=".$soft." idle=".$on_idle."\n";
					}else {
						system("$CLIENT -t float -n $cpu_group.$cpu_id.'_system' -v $system -g $cpu_group 2>/dev/null");	
						system("$CLIENT -t float -n $cpu_group.$cpu_id.'_iowait' -v $iowait -g $cpu_group 2>/dev/null");	
						system("$CLIENT -t float -n $cpu_group.$cpu_id.'_soft' -v $soft -g $cpu_group 2>/dev/null");	
						system("$CLIENT -t float -n $cpu_group.$cpu_id.'_idle' -v $on_idle -g $cpu_group 2>/dev/null");	
					}
				}
			}
			if($flagmatch == 0) {				
				return -7;			
			}			
			return TRUE;
		}
	} while( $? != 0 && $_[0] > 0 );

	return -7;
}

my $res = check_cpu_idle(0);

