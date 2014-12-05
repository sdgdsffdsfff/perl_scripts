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

my $slab_group = "slab";

my @tmp_res;
my @tmp_res2;

@tmp_res=`cat /proc/meminfo | grep -i slab 2>/dev/null`;
if ( $? == 0)
{
	chomp(@tmp_res);
	foreach my $line (@tmp_res)	 {
		chomp($line);
		@tmp_res2 = `echo "$line"| awk '{print \$1; print \$2; }' 2>/dev/null`;
		if ($? == 0)
		{
			chomp($tmp_res2[0]);
			$tmp_res2[0] =~ s/://;
			chomp($tmp_res2[1]);
			if ($debug) {
				print "key is $tmp_res2[0] and value is $tmp_res2[1]\n";
			} else {
				system("$CLIENT -t float -n $tmp_res2[0] -v $tmp_res2[1] -g $slab_group 2>/dev/null");
			}
		}
	}
}

@tmp_res=`cat /proc/slabinfo | egrep -e ip_vs_ipbl -e ip_vs_conn -e ip_dst_cache 2>/dev/null`;
if ( $? == 0)
{
	chomp(@tmp_res);
	foreach my $line (@tmp_res)	 {
		chomp($line);
		@tmp_res2 = `echo "$line"| awk '{print \$1; print \$3*\$4; }' 2>/dev/null`;
		if ($? == 0)
		{
			chomp($tmp_res2[0]);
			chomp($tmp_res2[1]);
			if ($debug) {
				print "key is $tmp_res2[0] and value is $tmp_res2[1]\n";
			} else {
				system("$CLIENT -t float -n $tmp_res2[0] -v $tmp_res2[1] -g $slab_group 2>/dev/null");
			}
		}
	}
}
