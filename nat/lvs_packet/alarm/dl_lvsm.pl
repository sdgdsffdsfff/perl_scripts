#!/usr/bin/perl
# $Description: A script to monitor lvs cluster. If there is something wrong with , it sends warning messages to monitors.

use File::Basename;
$MAIN_DIR=dirname($0);
require ($MAIN_DIR."/report.pl");

use LWP;
#use strict; 
use warnings;

##################
# basic variables
##################
## my true and false
use constant true => 1;
use constant TRUE => 1;
use constant false => 0;
use constant FALSE =>0;

## monitors' lists
my @mobile_list;
my @mail_list;

my $warn_msg;
my $date;
my $ret;

# modify by chenzhenchang: eliminate idle
#my $cpu_idle = 0.5;
# alarm: cpu soft > 80%; memory used > 80%
my $cpu_soft = 0.8;
my $memory_used = 0.8;
my $disk_used_rate = 0.8;

my $retry_number = 0;
my $retry;

my $arping_times = 3;
my $arp_eth = "eth1";

my $check_process_number = 0;
my %do_alarm_flag=();
my %process_pid = ();
my %process_target = (
        "keepalived"            => "/var/run/keepalived.pid",
        "vrrp"                  => "/var/run/vrrp.pid",
        "health_checker"        => "/var/run/checkers.pid",
        "bvs_daemon"            => "/var/run/bvs_daemon.pid"    

);
my $process_alarm_times = 3;

my %process_alarmed = (
	"keepalived"	    =>  0,
	"vrrp"		    =>  0,
	"health_checker"    =>	0,
	"bvs_daemon"	    =>	0
);

my $check_ipvs_number = 0;
my $check_healthcheck_number = 0;
my $cpu_idle_number = 0;
my $memory_free_number = 0;
my $disk_used_number = 0;
my $get_eth_up_number = 0;
my $get_STATE_change_number = 0;
my $get_hardware_number = 0;
my $default_gw_number = 0;
#healthcheck
my %healthcheck_none = ();
my %healthcheck_state = ();
my %healthcheck_numbers = ();
my %alarm_service = ();
my $nohealthcheck_times = 7 ;
my $g1_traf_alarm_th = 250;		## default: 70M
my $g10_traf_alarm_th = 70;
my $traf_times = 3;		## default: 3 times
my $last_traffic = 0;
my $traffic_alarm_interval = 5;
my $traffic_alarm_last = 0;

my %lvs_service_stat = ();
my $service_down_alarm_default = 3;
my $service_down_alarm_cycle = 5;

## alarm group define: sms_grp, email_grp, use by report.pl, global value, reference by report.pl
@sms_grp = ();
@email_grp = ();
my @modules_info = ();
my @rs_white_list = ();
my @vip_white_list = ();

my $cpu_data = 0;
my $memory_data = 0;
my $disk_used_data = 0;
my $disk_on = 0;

my $gsms="lvs_tcpdns_bjt";
my $gemail="";
my $ip_vs_check_time = 0;
my $proc_check_time = 0;
my $down_vs_list = "down_vs_list";
my $check_nic_connectedness = 1;
my %nic_alarm_table = ();


$ip_reg = "\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}";
$port_reg = "\\d{1,5}";

sub is_white_vip($)
{
	if (0 == $#vip_white_list + 1) {
		return 0;
	}
		
	for $i (0..$#vip_white_list) {
		if ($vip_white_list[$i] eq $_[0]) {
			print "vip $_[0] is in white list\n";
			return 1;
		}
	}
	return 0;
}

sub is_white_rs($)
{
	if (0 == $#rs_white_list + 1) {
		return 0;
	}
	for $i (0..$#rs_white_list) {
		if ($rs_white_list[$i] eq $_[0]) {
			print "rs $_[0] is in white list\n";
			return 1;
		}
	}
	return 0;
}

sub is_white_list($)
{
	my $msg = $_[0];
	my $rs_ip;
	my $vs;
	if ($msg =~ /^.*\[($ip_reg)\:($port_reg)\].*\[($ip_reg)\:($port_reg).*\]/) {
		$rs_ip = $1;
		$vs = "$3:$4";
	} elsif ($msg =~ /^.*\[($ip_reg)\:($port_reg)\].*/) {
		$vs = "$1:$2";
	}
	if ($vs) {
		if (is_white_vip($vs)) {
			return 1;
		}
	}
	if ($rs_ip) {
		return is_white_rs($rs_ip);
	}
	return 0;
}

# gsmsend/mail to monitors
# FIXME: mail support
sub alarm_monitors($$)
{
	$date = `/bin/date +%c`;
	$warn_msg = $_[0];
	my $rs_ip;
	my $vip;
	
	if (is_white_list($warn_msg)) {
		return;
	}
	
	chomp($date);
	print "$date: $warn_msg\n";
	&doAlarm($warn_msg, $warn_msg, $_[1], \%alarm_service);
}

sub alarm_monitors2($$$)
{
	$date = `/bin/date +%c`;
	
	my $title = $_[0];
	$warn_msg = $_[1];

	if (is_white_list($warn_msg)) {
		return;
	}
	
	chomp($date);
	print "$date: $title, $warn_msg\n";
	&doAlarm($title, $warn_msg, $_[2], \%alarm_service);
}

## commands
my $interval_time = 3;

my %tmp_info;

## processes to monitor, key is process name, value is the number of the processes should be running.
my %processes = ();
#my %processes = ("zebra"=>1, "ospfd"=>1, "keepalived"=>2);


#######################
# Basic functions 
#######################
# Show usage
sub usage()
{
	print "Usage: $0 <Configure File>\n";
}

## print config file informations
sub print_conf()
{
	print "alarm system config informations:\n";
	print "Processes:\n";
	foreach my $key (sort keys %processes)
	{
		print "$key:\t\t\t$processes{$key}\n";
	}
	print "Interval_time:\t\t\t$interval_time\n";
	print "retry_number:\t\t\t$retry_number\n";
	print "cpu_soft_threshold:\t\t$cpu_soft\n";
	print "memory_used_threshold:\t\t$memory_used\n";	
	print "disk_used_rate_threshold:\t$disk_used_rate\n";
	print "nohealthcheck_times:\t\t$nohealthcheck_times\n";

	print "sms alarm group:\t\t@sms_grp\n";
	print "email alarm group:\t\t@email_grp\n";

	print "lvs module depand define:\n";
	for $i (0..$#modules_info) {
		print "\t$modules_info[$i]\n";
	}

	print "vip white list:\n";
	for $i (0..$#vip_white_list) {
		print "\t$vip_white_list[$i]\n";
	}
	print "rs white list:\n";
	for $i (0..$#rs_white_list) {
		print "\t$rs_white_list[$i]\n";
	}
	print "10G traffic threshold:\t$g10_traf_alarm_th MB/s\n";
	print "1G traffic threshold:\t$g1_traf_alarm_th MB/s\n";
	print "traffic time:\t\t$traf_times\n";
#	print "traffic gap:\t\t$traffic_gap\n";
}

## point to percent: eg: 0.345->34.50%
sub ratio_format($)
{
	return sprintf("%0.2f", $_[0] * 100)."%";
}

sub get_cur_time()
{    
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my $date = $hour * 60 + $min;
    return $date;
}

# check whether the process is running on the server. this is used to check zebra, ospfd, keepalived
# param $_[0] process name
# param $_[1] retry time 
# return number of processes running on the machine, -1 means failed to get.
sub check_process($$)
{
	do
	{
		my $sshcmd = "/sbin/pidof -x $_[0]";
		my $res = `$sshcmd 2>/dev/null 0</dev/null`;
		if($? == 0)
		{
			chomp($res);
			my @tmp = split(" ", $res);
			return $#tmp+1;
		}
		$_[1] = $_[1]-1;
	}while( $? !=0 && $_[1] >0 );

	return -7;
}

## check whether the ip_vs module is loaded---new
sub check_ip_vs_loaded($)
{
	my $rule = "^\\s*(";
	for $j (0..$#modules_info) {
		$rule .= "\\b$modules_info[$j]\\b|";
	}
	$rule =~ s/\|$//g;
	$rule .= ")";

	do {
		my $chkcmd = "/sbin/lsmod";
		my @res = `$chkcmd 2>/dev/null 0</dev/null`;
		if( $? == 0 ) {
			my $i = 0;
			chomp(@res);
			foreach my $line (@res) {
				if($line =~ /$rule/) {
					$i++;
				}
			}
			$module_num = $#modules_info + 1;
			if ($i == $module_num) {
				return TRUE;
			} else {
				return FALSE;
			}
		}
		$_[0]= $_[0]-1;
	} while( $? != 0 && $_[0] > 0 );
	return -7; 
}

# check whether the ip_vs module is loaded ---old
sub check_ip_vs_loaded_old($)
{
	do
	{
		my $chkcmd = "/sbin/lsmod";
		my @res = `$chkcmd 2>/dev/null 0</dev/null`;
		if( $? == 0 )
		{
			my $i = 0;
			chomp(@res);
			foreach my $line (@res)
			{
				if($line =~ /^\s*(\bip_vs\b|\bip_vs_wrr\b|\bip_vs_rr\b)/)
				{
					$i++;
				}
			}
			if($i == 2)
			{
				return TRUE;
			}
			else
			{
				return FALSE;
			}
		}
		$_[0]= $_[0]-1;
	}while( $? != 0 && $_[0] > 0 );
	return -7;
}

# check whether the healthcheck have down.
sub healthcheck($)
{
	do
	{
		my $ipvscmd = "/sbin/ipvsadm -ln";
		my @res = `$ipvscmd 2>/dev/null 0</dev/null`;
		if($? == 0)
		{
			if($check_healthcheck_number == -7)
			{
				$check_healthcheck_number = 0;
				$warn_msg="success to get healthcheck num";
				alarm_monitors($warn_msg, 1);
			}
			chomp(@res);
			my $vip_address;
			my $vip_rs;

			foreach my $line (@res)
			{
				if ($line =~ /TCP\s+([0-9\.]+):.*/)
				{
					$vip_address = $1;
				}
				elsif ($line =~ /\s+-.*?([0-9\.]+):(.*?\s+){5}([0-9]+)/)
				{
					$vip_rs = $vip_address." connect to rs ".$1;
					if ( $healthcheck_state{$vip_rs} eq "")
					{
						$healthcheck_state{$vip_rs} = "OK";
						$healthcheck_none{$vip_rs} = 0;
						$healthcheck_numbers{$vip_rs} = $3;
					}
					else
					{	
						if($3==$healthcheck_numbers{$vip_rs})
						{
							$healthcheck_none{$vip_rs} = $healthcheck_none{$vip_rs}+1;
						}
						else
						{
							$healthcheck_none{$vip_rs} = 0;
							$healthcheck_numbers{$vip_rs} = $3;
						}
					}

					if ($healthcheck_state{$vip_rs} eq "OK" and $healthcheck_none{$vip_rs} > $nohealthcheck_times)
					{
						$warn_msg="keepalived: vip $vip_rs has not been done!";
						alarm_monitors($warn_msg, 1);
						$healthcheck_state{$vip_rs} = "BAD";
					}
					elsif ($healthcheck_state{$vip_rs} eq "BAD" and $healthcheck_none{$vip_rs} == 0)
					{
						$warn_msg="keepalived: vip $vip_rs has been done!";
						alarm_monitors($warn_msg, 1);
						$healthcheck_state{$vip_rs} = "OK";
					}	
				}
			}
		}
		$_[0] = $_[0]-1;
	}while($_[0] > 0 && $? != 0 );
	if($_[0] <= 0)
	{
		if($check_healthcheck_number != -7)
		{
			$check_healthcheck_number = -7;
			$warn_msg="Failed to get healthcheck numbers";
			alarm_monitors($warn_msg, 1);
		}
	}
}

# check whether the cpu_idle>threshold
sub check_cpu_soft($)
{
	do
	{
		my $chkcmd = "LC_ALL=C /usr/bin/mpstat -P ALL 3 1";
		my @res = `$chkcmd 2>/dev/null 0</dev/null`;
		if( $? == 0 )
		{
			chomp(@res);
			my $flagmatch = 0;
			foreach my $line (@res)
			{
				if ($line =~ /Average:\s+([0-9]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)/)
				{
					my $iowait = $5;
					my $on_idle = $9;
					my $idle = ($on_idle+$iowait)/100;
					my $soft = $7/100;
					if($soft > $cpu_soft )
					{
						#$cpu_data = "iowait=".$iowait.",user=".$2.",sys=".$4.",soft=".$7.",id=".$1;
						$cpu_data = "soft=".ratio_format($soft).",idle=".ratio_format($idle).",cpu=".$1;
						`/home/bvs-manager/bvs/spflow.pl stop`;
						return FALSE;
					}
					$flagmatch = 1;
				}
			}
			if($flagmatch == 0)
			{
				return -7;
			}
			return TRUE;
		}
		$_[0] = $_[0]-1;
	}while( $? != 0 && $_[0] > 0 );

	return -7;
}       

# check whether the memory_used<threshold
sub check_memory_free($)
{
	my $mem_total = 0;
	do
	{
		my $chkcmd = "/usr/bin/free";
		my $res = `$chkcmd 2>/dev/null 0</dev/null`;
		if( $? == 0 )
		{
			my $tmp;
			chomp($res);
			
			## get mem total
			if ($res =~ /Mem:[\s\t]+([0-9]+)/s) {
				$mem_total = $1;
			} else {
				return FALSE;
			}
			if($res =~ /-\/\+[\s\t]+buffers\/cache:[\s\t]+([0-9]+)[\s\t]+([0-9]+)/s)
			{
				$memory_data = $1/$mem_total;
				if($memory_data > ($memory_used))
				{	
					return FALSE;
				}
				return TRUE;
			}
			return -7;
		}
		$_[0] = $_[0]-1;
	}while( $? != 0 && $_[0] > 0 );
	return -7;
}    

# check whether the disk is over-used
sub check_disk_used($)
{
	do
	{
		my $chkcmd = "/bin/df";
		my @res = `$chkcmd 2>/dev/null 0</dev/null`;
		if( $? == 0 )
		{
			chomp(@res);
			my $flagmatch = 0;
			foreach my $line (@res)
			{
				#if($line =~ /^\/dev\/[\w\/]+\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+([0-9]+)\%\s+([\/\w]+)$/)
				if($line =~ /\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+([0-9]+)\%\s+([\/\w]+)$/)
				{	
					my $rate = $1/100;
					$disk_on = $2;
					if( $rate > $disk_used_rate)
					{
						$disk_used_data = $rate;
						#$disk_used_data = "disk on ".$disk_on." have been used ".ratio_format($rate);
						return FALSE;
					}
					$flagmatch = 1;
				}
			}
			if($flagmatch == 0)
			{
				return -7;
			}
			return TRUE;
		}
		$_[0] = $_[0]-1;
	}while( $? != 0 && $_[0] > 0 );
	return -7;
}

# check whether ethx is up
# param[0]: flag whether it's the first time to run
# param[1]: retry time
sub check_eth_up($$)
{
	my $flag = $_[0];
	my $chkcmd;
	my $res;
	my @array;
	my $cflag = 0;
	if($flag == 0)  #initial_state
	{
		do
		{
			$chkcmd = "/bin/dmesg >> /var/log/dmesg.bak ;dmesg -c > /dev/null";
			$res = `$chkcmd 2>/dev/null 0</dev/null`;
			print "check_eth_up_initial\n:";
			if( $? == 0 )
			{
				print "check_eth_up_initial_allright:\n";
			}
			$_[1] = $_[1]-1;
		}while( $? != 0 && $_[1] > 0 );
		if( $_[1] <= 0 )
		{
			$warn_msg="Failed to cleanup dmesg!";
			alarm_monitors($warn_msg, 1);
		}
	}
	else
	{ 
		do
		{
			$chkcmd = "/bin/dmesg";
			@array = `$chkcmd 2>/dev/null 0</dev/null`;
			if( $? == 0 )
			{
				if($get_eth_up_number == -7)
				{
					$get_eth_up_number = 0;
					$warn_msg="success to get dmesg";
					alarm_monitors($warn_msg, 1);
				}
				chomp(@array);
				foreach my $line (@array)
				{
					if($line =~ /.*?(eth\d).*?(\bup\b).*/i)
					{
						$warn_msg="$1:NIC Link is Up!";
						alarm_monitors($warn_msg, 1);
						if($cflag == 0)
						{
							$chkcmd = "dmesg >> /var/log/dmesg.bak ;dmesg -c > /dev/null";
							$res = `$chkcmd 2>/dev/null 0</dev/null`;
							$cflag = 1;
						}
					} elsif ($line =~ /.*?(eth\d).*?(\bDown\b).*/i) {
						$warn_msg="$1:NIC Link is Down!";
						alarm_monitors($warn_msg, 1);
						if($cflag == 0)
						{
							$chkcmd = "dmesg >> /var/log/dmesg.bak ;dmesg -c > /dev/null";
							$res = `$chkcmd 2>/dev/null 0</dev/null`;
							$cflag = 1;
						}
					}
				}
				if($cflag == 0 and $#array > 1000)
				{
					$chkcmd = "/bin/dmesg >> /var/log/dmesg.bak ;dmesg -c > /dev/null";
					$res = `$chkcmd 2>/dev/null 0</dev/null`;
				}
			}
			$_[1] = $_[1]-1;
		}while( $? != 0 && $_[1] > 0 );
		if($_[1] <= 0)
		{
			if($get_eth_up_number != -7)
			{
				$get_eth_up_number = -7;
				$warn_msg="Failed to get dmesg";
				alarm_monitors($warn_msg, 1);
			}
		}
	}
}

# check hardware 

sub check_hardware($$)
{
	my $flag = $_[0];
	my $times = $_[1];
	my $chkcmd;
	my $res;
	my @array;
	my $cflag = 0;
	if($flag == 0)  #initial_state
	{
		do
		{
			$chkcmd = "cat /var/log/mcelog >> /var/log/mcelog.bak ; echo \"\" > /var/log/mcelog";
			$res = `$chkcmd 2>/dev/null 0</dev/null`;
			print "check_hardware_initial:\n";
			if( $? == 0 )
			{
				print "check_hardware_initial_allright:\n";
			}
			$times = $times-1;
		}while( $? != 0 && $times > 0 );
		if( $times <= 0 )
		{
			$warn_msg="Failed to cleanup /var/log/mcelog!";                   
			alarm_monitors($warn_msg, 1);                                                                  
		} 
	}
	else
	{
		do
		{
			$chkcmd = "cat /var/log/mcelog";
			@array = `$chkcmd 2>/dev/null 0</dev/null`;
			if( $? == 0 )
			{
				if($get_hardware_number == -7)
				{                                                                                
					$get_hardware_number = 0;
					$warn_msg="$_[0]: success to get /var/log/mcelog";
					alarm_monitors($warn_msg, 1);                                             
				}
				chomp(@array);
				foreach my $line (@array)
				{
					my $found=0;
					if($line =~ /^HARDWARE ERROR.*/ ) 
					{
						$warn_msg="Hardware error!";
						alarm_monitors($warn_msg, 1);
						$found = 1;
					} elsif ($line =~ /^Transaction: Memory scrubbing error/ ) {
					        $warn_msg="Memory scrubbing error!";
						alarm_monitors($warn_msg, 1);
						$found = 1;
					}
					
					if($cflag == 0 and $found == 1)
					{
						$chkcmd = "cat /var/log/mcelog >> /var/log/mcelog.bak ; echo \"\" > /var/log/mcelog";
						$res = `$chkcmd 2>/dev/null 0</dev/null`;
						$cflag = 1;
					}

				}

				if($cflag == 0 and $#array > 1000)
				{
					$chkcmd = "cat /var/log/mcelog >> /var/log/mcelog.bak ; echo \"\" > /var/log/mcelog";
					$res = `$chkcmd 2>/dev/null 0</dev/null`;
				}
			}
			$times = $times-1;
		} while ( $? != 0 && $times > 0 );
		if($times <= 0)                                                                                            
		{                                                                                                         
			if($get_hardware_number != -7)         
			{                                                                                                  
				$get_hardware_number = -7;                                                             
				$warn_msg="Failed to get /var/log/mcelog";
				alarm_monitors($warn_msg, 1);
			}
		}
	}
}


# check whether lvs state is changed
# param[0]: flag, whether is first time to run;
# param[1]: retry time
sub check_STATE_change($$)
{
	my $flag = $_[0];
	my $chkcmd;
	my $res;
	my @array;
	my $cflag = 0;
	if($flag == 0)  #initial_state
	{
		do
		{
			$chkcmd = "cat /var/log/messages >> /var/log/messages.bak ; echo \"\" > /var/log/messages";
			$res = `$chkcmd 2>/dev/null 0</dev/null`;
			print "check_STATE_change_initial:\n";
			if( $? == 0 )
			{
				print "check_STATE_change_initial_allright:\n";
			}
			$_[1] = $_[1]-1;
		}while( $? != 0 && $_[1] > 0 );

		if( $_[1] <= 0 )
		{
			$warn_msg="Failed to cleanup /var/log/messages!";                   
			alarm_monitors($warn_msg, 1);                                                                            
		} 
	}
	else
	{
		do
		{
			$chkcmd = "cat /var/log/messages";
			@array = `$chkcmd 2>/dev/null 0</dev/null`;
			if( $? == 0 )
			{
				if($get_STATE_change_number == -7)                                                                      
				{                                                                                                 
					$get_STATE_change_number = 0;                                                                       
					$warn_msg="$_[0]: success to get /var/log/messages";                                     
					alarm_monitors($warn_msg, 1);                                                                    
				}
				chomp(@array);
				foreach my $line (@array)
				{
					my $found=0;
					if($line =~ /.*?Keepalived_vrrp: VRRP_Instance\((.*?)\)\s(Entering\s[A-Z]*?\sSTATE)/ )
					{
						$warn_msg="vrrp:$2!";
						alarm_monitors($warn_msg, 1);
						$found = 1;
					} elsif ($line =~ /.*?Keepalived_healthcheckers: Disabling service (\[.*?\])\sfrom VS\s(\[.*?\])/ ) {
						my $title = "RS $1 for VS $2 is down";
					        $warn_msg="RS $1 for VS $2, health checker FAILED!";
						alarm_monitors2($title, $warn_msg, 0);
						$found = 1;
					} elsif ($line =~ /.*?Keepalived_healthcheckers: Removing service (\[.*?\])\sfrom VS\s(\[.*?\])/ ) {
						my $title = "RS $1 for VS $2 is down";
						$warn_msg="RS $1 for VS $2, health checker FAILED!";
						alarm_monitors2($title, $warn_msg, 0);
						$found = 1;
					} elsif ($line =~ /.*?Keepalived_healthcheckers: Enabling service (\[.*?\])\sto VS\s(\[.*?\])/ ) {
						my $rs = $1;
						my @vs = $2 =~ /\[(.*?)\]/gs;
						my @info = split(/:/, $vs[0]);
						my $vip = $info[0];
						my $vport = $info[1];
						if (defined $lvs_service_stat{$vs[0]} and $lvs_service_stat{$vs[0]}[0] eq "DOWN") {
						    delete $lvs_service_stat{$vs[0]};
						    $warn_msg = "VS [$vs[0]] is UP!";
						    alarm_monitors($warn_msg, 1);
						    update_down_vs_list($vip, $vport, 0);
						}
						my $title = "RS $rs for VS [$vs[0]] is up";
						$warn_msg="RS $rs for VS [$vs[0]], health checker SUCCESS!";
						alarm_monitors2($title, $warn_msg, 0);
						$found = 1;
					} elsif ($line =~ /.*?Keepalived_healthcheckers: Adding service (\[.*?\])\sto VS\s(\[.*?\])/ ) {
						my $title = "RS $1 for VS $2 is up";
						$warn_msg="RS $1 for VS $2, health checker SUCCESS!";
						alarm_monitors2($title, $warn_msg, 0);
						$found = 1;
					} elsif ($line =~ /.*?Keepalived_healthcheckers: VS (\[.*?\])\srs_alive_ratio \(.*?%\) <= rs_alive_ratio_down \(.*?%\), notify the vrrp instance to decrease priority./ ) {
						$warn_msg="VS $1 is DOWN!";
						my @vs = $1 =~ /\[(.*?)\]/gs;
						$lvs_service_stat{$vs[0]}[0] = "DOWN";
						$lvs_service_stat{$vs[0]}[1] = 1;
						$lvs_service_stat{$vs[0]}[2] = get_cur_time();
						my @info = split(/:/, $vs[0]);
						my $vip = $info[0];
						my $vport = $info[1];
						if (!is_vs_always_down($vip, $vport)) {
						    alarm_monitors($warn_msg, 1);
						}
						$found = 1;
					} elsif ($line =~ /.*?kernel.*.intel_idle/) {
						$warn_msg="system panic!";
						alarm_monitors($warn_msg, 1);
						$found = 1;
					} elsif ($line =~ /connection count exceed ip_vs_conn_max: ([0-9]+). refused/ or $line =~ /connection count exceeded ip_vs_max_conn: ([0-9]+). refused/) {
						$warn_msg = "conn exceeded: $1";
						alarm_monitors($warn_msg, 1);
						$found = 1;
#					} elsif ($line =~ /(\w+\s+\d+\s+\d+:\d+:\d+)\s+\w+\s+kernel: IPVS: add ipbl\s+(\d+\.\d+\.\d+\.\d+)\[(\d+):(\d+)\]:\s+\[(\d+),\s+(\d+),\s+(\d+),\s+(\d+)\]/) {
#						$warn_msg = "add ipbl: $2";
#						$found = 1;
#						alarm_monitors($warn_msg, 1);
					}


					if($cflag == 0 and $found == 1)
					{
						$chkcmd = "cat /var/log/messages >> /var/log/messages.bak ; echo \"\" > /var/log/messages";
						$res = `$chkcmd 2>/dev/null 0</dev/null`;
						$cflag = 1;
					}

				}

				if($cflag == 0 and $#array > 1000)
				{
					$chkcmd = "cat /var/log/messages >> /var/log/messages.bak ; echo \"\" > /var/log/messages";
					$res = `$chkcmd 2>/dev/null 0</dev/null`;
				}
			}
			$_[1] = $_[1]-1;
		}while( $? != 0 && $_[1] > 0 );
		if($_[1] <= 0)                                                                                            
		{                                                                                                         
			if($get_STATE_change_number != -7)                                                                          
			{                                                                                                     
				$get_STATE_change_number = -7;                                                                          
				$warn_msg="Failed to get /var/log/messages";
				alarm_monitors($warn_msg, 1);                                                                        
			}                                                                                                     
		}
	}
}

# check whether the synproxy is running in auto mode
sub check_syn_proxy_auto()
{
	my $chkcmd = "cat /proc/sys/net/ipv4/vs/syn_proxy_auto";
	my $res = `$chkcmd 2>/dev/null 0</dev/null`;
	chomp($res);
	if($? == 0 and $res eq "1")
	{
		return TRUE;
	}
	return FALSE;
}

# check whether the synproxy is started
sub check_syn_proxy_entry()
{
	my $chkcmd = "cat /proc/sys/net/ipv4/vs/syn_proxy_entry";
	my $res = `$chkcmd 2>/dev/null 0</dev/null`;
	chomp($res);
	if($? == 0 and $res eq "1")
	{
		return TRUE;
	}
	return FALSE;
}

# Check whether the default gateway changed
sub default_gw_changed($)
{
	do
	{
		my $chkcmd = "/sbin/route -n";
		my @res = `$chkcmd 2>/dev/null 0</dev/null`;
		if($? == 0)
		{
			$ret = "";
			chomp(@res);
			foreach my $line (@res)
			{
				if($line =~ /^0\.0\.0\.0\s+([0-9\.]+).*/)
				{
					$ret = $1;
				}
			}
			return $ret;
		}
		$_[1] = $_[1]-1;
	}while( $? != 0 && $_[1] > 0 );

	$ret = "0.0.0.0";
	return $ret;
}

# Check traffic on each nic
sub check_traffic($$)
{
    my $max_traf = 0;
    my $times = $_[1];
    my $total = 0;
    my $avg = 0;
    my $flag = 0;
    my $count = 0;

    my $kbyte=`LC_ALL=C /usr/bin/sar -n DEV 0 | grep IFACE | awk '{print \$5}'`;
    chomp $kbyte;

    do {
	my $chkcmd = "LC_ALL=C /usr/bin/sar -n DEV 2 2 | grep '^Average: ' | grep -v 'IFACE' | awk '{print \$5, \$6}' | tr '\n' ' '";
	my $buff = `$chkcmd 2>/dev/null`;
	$avg = 0;
	if ($? == 0) {
	    my @res = split(" ", $buff);
	    chomp(@res);
	    foreach my $value (@res) {
		if ($kbyte =~ /rxkB\/s/) {
		    $value = $value*1024;
		}
		$total += int($value);
		$count++;
		my $tmp = int($value / 1024 / 1024);
		$max_traf = ($max_traf < $tmp) ? $tmp:$max_traf;
	    }
	    if ($flag == 0 and $max_traf <= $traf_alarm_th) {
		return FALSE;
		$flag = 1;
	    }
	    $times = $times - 1;
	}
    } while ($times > 0);

#print "warn_msg: $warn_msg\n";
    $avg = int($total / $count);
    if ($traf_alarm_th != 0) {
	$warn_msg = "rxbyt/txbyt: $max_traf(MB/s) > $traf_alarm_th(MB/s)!";
	alarm_monitors($warn_msg, 1);
    }
    if ($last_traffic != 0 and 0) {
	my $gap = int(abs($last_traffic - $avg) * 100 / $last_traffic);
	if ($gap > $traffic_gap) {
	    $warn_msg = "traffic up/down: $gap% > $traffic_gap%!";
	    alarm_monitors($warn_msg, 1);
	}
    }
    $last_traffic = $avg;
    return TRUE;
}

sub check_traffic2($)
{
    if ($_[0] == 0) {
	return;
    }
    my $kbyte=`LC_ALL=C /usr/bin/sar -n DEV 0 | grep IFACE | awk '{print \$5}'`;
    chomp $kbyte;
    my $traffic = 0;
    my $cmd = "LC_ALL=C /usr/bin/sar -n DEV 2 1";
    my $res = `$cmd >/tmp/traffic_info 2>/dev/null `;
    
    foreach my $nic (keys(%nic_alarm_table)) {
	my $cmd1 = "cat /tmp/traffic_info | grep $nic | grep Average | awk '{if (\$5 > \$6) a=\$5; else a=\$6;}END{print a}'";
	my $res1 = `$cmd1 2>/dev/null`;
	chomp $res1;
	if ($? == 0) {
	    chomp($traffic);
	    if ($kbyte =~ /rxkB\/s/) {
		$res1 = $res1*1024;
	    }
	    $traffic = int($res1 / 1024 / 1024);
	    if ($nic_alarm_table{"$nic"}[0] == 1) {
		if ($traffic > $g10_traf_alarm_th) {
		    $nic_alarm_table{"$nic"}[1]++;
		} else {
		    $nic_alarm_table{"$nic"}[1] = 0;
		}
	    } else {
		if ($traffic > $g1_traf_alarm_th) {
		    $nic_alarm_table{"$nic"}[1]++;
		} else {
		    $nic_alarm_table{"$nic"}[1] = 0;
		}
	    }
	    if ($nic_alarm_table{"$nic"}[1] >= $traf_times) {
		$nic_alarm_table{"$nic"}[1] = 0;
		my $warn_msg = "$nic overload: $traffic MB/s";
		if ($traffic_alarm_last == 0) {
		    $traffic_alarm_last = get_cur_time();
		    alarm_monitors($warn_msg, 1);
		} else {
		    my $cur_time = get_cur_time();
		    if ($cur_time - $traffic_alarm_last >= $traffic_alarm_interval) {
			$traffic_alarm_last = $cur_time;
			alarm_monitors($warn_msg, 1);
		    }
		}
	    }
	}
    }
}

sub check_network()
{
    if ( "$arp_eth" eq "" or $check_nic_connectedness == 0) {
	return;
    }

    my @info = `/sbin/ifconfig $arp_eth`;
    my $gateway = "";
    my $i = 0;

    foreach $line (@info) {
	chomp $line;
	if ($line =~ /\s+inet\s+addr:(\d+.\d+.\d+.\d+)\s+Bcast:(\d+.\d+.\d+.\d+)\s+Mask:(\d+.\d+.\d+.\d+)/) {
	    my $ip = $1;
	    my $bcast = $2;
	    my $mask = $3;

	    chomp $ip; 
	    chomp $bcast;
	    chomp $mask;

	    my $bcast_int = unpack('N*', pack('C4', split(/\./, "$bcast")));
	    my $mask_int = unpack('N*', pack('C4', split(/\./, "$mask")));

	    $gateway_int = $bcast_int & $mask_int + 1;

	    my $a = $gateway_int>>24;
	    my $b = (($gateway_int<<8)&0xffffffff)>>24;
	    my $c = (($gateway_int<<16)&0xffffffff)>>24;
	    my $d = (($gateway_int<<24)&0xffffffff)>>24; 
	    $gateway = "$a.$b.$c.$d";
	}
    }
    if ("$gateway" ne "") {
	while ($i < $arping_times) {
#	    my @res = `/sbin/arping -c 1 -I $arp_eth $gateway`;
#
#	    foreach my $line (@res) {
#		chomp $line;
#		if ($line =~ /^Unicast reply from $gateway/) {
#		    return;
#		}
#	    }
	    my @res = `ping -I $arp_eth -c 1 $gateway`;
	    if ($? == 0) {
		return;	
	    }
	    $i++;
	    sleep 1
	}
	my $warn_msg = "ping -I $arp_eth gateway failed!\n";
	alarm_monitors($warn_msg, 1);
#    } else {
#	my $warn_msg = "can not get $arp_eth info!\n";
#	alarm_monitors($warn_msg, 1);
    }

    return;
}

sub update_down_vs_list($$$)
{
    my $vip = $_[0];
    my $vport = $_[1];
    my $flag = $_[2];
    my $found = 0;

    my @down_vs = `cat $down_vs_list`;
    my @new_down_vs;

    foreach my $vs (@down_vs) {
	chomp $vs;
	if ($vs eq "$vip:$vport") {
	    $found = 1;
	    if ($flag == 0) {
		next;
	    }
	    push(@new_down_vs, "$vs\n");
	} else {
	    push(@new_down_vs, "$vs\n");
	}
    }
    if ($found == 0 && $flag == 1) {
	push (@new_down_vs, "$vip:$vport\n");
    }
    open FD, ">$down_vs_list" or die("Could not open $down_vs_list!\n");
    print FD @new_down_vs;
    close(FD);
}

sub is_vs_always_down($$)
{
    my $vip = $_[0];
    my $vport = $_[1];

    my @down_vs = `cat $down_vs_list`;
    foreach my $vs (@down_vs) {
	chomp $vs;
	if ($vs eq "$vip:$vport") {
	    return 1;
	}
    }
    return 0;
}

sub check_down_service()
{
    my $cur_time = get_cur_time();
    foreach my $key (keys %lvs_service_stat) {
	if (defined $lvs_service_stat{$key} and $lvs_service_stat{$key}[0] eq "DOWN") {
	    if ($cur_time - $lvs_service_stat{$key}[2] >= $service_down_alarm_cycle) {
		my @info = split(/:/, $key);
		my $vip = $info[0];
		my $vport = $info[1];
		if ($lvs_service_stat{$key}[1] < $service_down_alarm_default) {
		    if (!is_vs_always_down($vip, $vport)) {
			$warn_msg="VS [$key] is DOWN!";
			alarm_monitors($warn_msg, 1);
			$lvs_service_stat{$key}[1]++;
			$lvs_service_stat{$key}[2] = $cur_time;
		    }
		} else {
		    update_down_vs_list($vip, $vport, 1);
		    delete $lvs_service_stat{$key};
		}
	    }
	}
    }
}

# get the configurations
sub get_config($)
{
	my $all_lines;
	my $threshold ;
	my $i = 0;
	my $j = 0;
	my $k = 0;

	open CONF_FILE, "<$_[0]" or die("Could not open configure file!\n");
	while(<CONF_FILE>)
	{
		if(/threshold\s*\{/../\}/)
		{
			if($_ =~ /^\s*cpu_soft\s*\=\s*([0-9\.]+)\s*;/)
			{
				$threshold = $1 ;
				if( $threshold =~ /^[0-9]*(\.)?[0-9]+$/ )
				{
					$cpu_soft = $threshold;
				}
			}
			elsif($_ =~ /^\s*memory_used\s*\=\s*([0-9\.]+)\s*;/)
			{
				$threshold = $1 ;
				if( $threshold =~ /^[0-9]*(\.)?[0-9]+$/ )
				{
					$memory_used = $threshold ;
				}
			}
			elsif($_ =~ /^\s*disk_used_rate\s*\=\s*([0-9\.]+)\s*;/)
			{
				$threshold = $1 ;
				if( $threshold =~ /^[0-9]*(\.)?[0-9]+$/ )
				{
					$disk_used_rate = $threshold ;
				}
			}
			elsif ($_ =~ /^\s*10g_traffic\s*\=\s*([0-9\.]+)\s*;/) {
			    $g10_traf_alarm_th = $1;
			} elsif ($_ =~ /^\s*1g_traffic\s*\=\s*([0-9\.]+)\s*;/) {
			    $g1_traf_alarm_th = $1;
			} elsif ($_ =~ /^\s*traffic_times\s*\=\s*([0-9\.]+)\s*;/) {
			    $traf_times = $1;
			} elsif ($_ =~ /^\s*traffic_gap\s*\=\s*([0-9\.]+)\s*;/) {
			    $traffic_gap = $1;
			} elsif ($_ =~ /^\s*check_nic_connectedness\s*\=\s*([0-9\.]+)\s*;/) {
			    $check_nic_connectedness = $1;
			}
		}
		elsif(/healthcheck\s*\{/../\}/)
		{
			if($_ =~ /^\s*nohealthcheck_times\s*\=\s*([0-9]+)\s*;/)
			{
				$nohealthcheck_times = $1;
			}
		}
		elsif(/time\s*\{/../\}/)
		{
			if($_ =~ /^\s*interval_time\s*\=\s*([0-9]+)\s*;/)
			{
				$interval_time = $1;
			}
			elsif($_ =~ /^\s*retry_number\s*\=\s*([0-9]+)\s*;/)
			{
				$retry_number = $1;
			}
		}
		elsif(/processes\s*\{/../\}/)
		{
			if($_ =~/^\s*([\w\-]+)\s*\=\s*([0-9]+)\s*;/)
			{
				$processes{$1} = $2;
				$do_alarm_flag{$1}=0;
			}
		}  elsif (/sms_group\s*\{/../\}/) {
			if ($_ !~ /^sms_group/ && $_ !~ /\}/ && $_ !~ /^\s*#/) {
				chomp($_);
				$_ =~ s/(^\s+|\s+$|;)//g;
				$sms_grp[$i++] = $_;
			}
		} elsif (/email_group\s*\{/../\}/) {
			if ($_ !~ /^email_group/ && $_ !~ /\}/ && $_ !~ /^\s*#/) {
				chomp($_);
				$_ =~ s/(^\s+|\s+$|;)//g;
				$email_grp[$j++] = $_;
			}
		
		} elsif (/modules\s*\{/../\}/) {
			if ($_ =~ /^\s*lvs_modules\s*\=\s*(.+)\s*;/) {	
				push @modules_info, split(/:/, $1);
			}
		} elsif (/rs_white_list\s*\{/../\}/) {
			if ($_ !~ /^rs_white_list/ && $_ !~ /\}/ && $_ !~ /^\s*#/ ) {
				$_ =~ s/(^\s+|\s+$|;)//g;
				my $index = $#rs_white_list + 1;
				$rs_white_list[$index] = $_;
			}
		} elsif (/vip_white_list\s*\{/../\}/) {
			if ($_ !~ /^vip_white_list/ && $_ !~ /\}/ && $_ !~ /^\s*#/ ) {
				$_ =~ s/(^\s+|\s+$|;)//g;
				my $index = $#vip_white_list + 1;
				$vip_white_list[$index] = $_;
			}
		} else {
			print "unknown cmd: $_\n";
		}
	}
	
#	print "\nProcesses:\n";
#	foreach my $key (keys %processes )
#	{
#		print "$key: $processes{$key}\n";
#	}
#	print "Interval_time:$interval_time\n";
#	print "retry_number:$retry_number\n";
#	print "cpu_soft_threshold:$cpu_soft\n";
#	print "memory_used_threshold:$memory_used\n";	
#	print "disk_used_rate_threshold:$disk_used_rate\n";
#	print "nohealthcheck_times:$nohealthcheck_times\n";

	close CONF_FILE;
}


sub get_alarm_service_old($)
{
    open CONF_FILE, "<$_[0]" or die("Could not alarm config configure file!\n");
    while(<CONF_FILE>) {
	if ($_ =~ /^\s*#/) {
	    next;
	}
	if ($_ =~ /([\w\.]+):([\w\.]*):([\w\-\|]*):([\w\-\|]*)/) {
	    my @serv_info = ($2, $3, $4);
	    $alarm_service{"$1"} = \@serv_info;
	}
    }
    close CONF_FILE;
}

sub get_alarm_service($)
{
    my @alarms = `cat $_[0]`;

    foreach my $line (@alarms) {
	chomp $line;
	if ($line =~ /^\s*#/) {
	    next;
	}
	if ($line =~ /([\w\.]+):([\w\.]*):([\w\-\|]*):([\w\-\|]*)/) {
	    my @serv_info = ($2, $3, $4);
	    $alarm_service{"$1"} = \@serv_info;
	}
    }
    
}

sub init_pid_diff ( )
{
        my $pid;
	my $status=0;
        my $ret_string="";
        my $key;
        my $value;
        my $err_process="";

        while ( ($key,$value)=each %process_target){
		$pid = 0;
		if (-e $value) {
			open FD,$value ;
			if ($? == 0) {
				$pid = <FD>;
				chomp $pid; 
				if ($pid eq "") {
					$pid = 0;
				}
			}
			close(FD);
		}
		$process_pid{$key} = $pid;
        }
        if($status == 1){
                $ret_string="process check init failed";
        }else{
                $ret_string= "process check init success";
        }
        return ($status,$ret_string);

}
#  monitore keepalived process respwan
sub diff_process_pid ($)
{

        my $key;
        my $value;
        my $ret_string="";
	my $init_string= "";
        my $status=0;
        my $pid;
        my $fd;
	my $is_running =$_[0];
        if(!$is_running){
                $status,$init_string=init_pid_diff();
                if($status != 0 ){
                        alarm_monitors($ret_string,1);
                }else {
                        $is_running =1;
                }
		print "$init_string\n";
                return $status;
        }

        while ( ($key,$value)=each %process_target){
		$pid = 0;
		if (-e $value) {
			open FD,$value;
			if ($? == 0) {
				$pid = <FD>;
				chomp $pid;
				if ($pid eq "") {
				    $pid = 0;
				}
			}
			close(FD);
		}
		if ($process_pid{$key} == 0) {
			if ($pid != 0) {
				$process_alarmed{$key} = 0;
				$process_pid{$key} = $pid;
				$ret_string = "$key change from 0 to $pid!";
				alarm_monitors($ret_string,1);
			}  elsif ($process_alarmed{$key} < $process_alarm_times) {
				$ret_string = "$key pid not exist!";
				alarm_monitors($ret_string,1);
				$process_alarmed{$key}++;
			}
		} else {
		        if ($pid == 0 or $process_pid{$key} != $pid) {
				$ret_string = "$key change from $process_pid{$key} to $pid!";
				alarm_monitors($ret_string,1);
				$process_pid{$key} = $pid;
				$process_alarmed{$key} = 0;
			}
		}
        }

}

# check all the servers with ping, ssh, curl ...
# param $_[0] 0 means called by init initial_servers(), 1 means we should cehck the old status.
sub check_all_servers($)
{	
	my $flag = $_[0];
	my $warn_msg;
	my $ip2;
	my $ip1;
	my $server;
	{	
## check whether ip_vs is loaded and used  
		$retry = $retry_number;
		my $res = check_ip_vs_loaded($retry);
		if( $res == -7)
		{
			if($check_ipvs_number != -7)                                                           
			{                                                                                         
				$check_ipvs_number = -7;                                                           
				$warn_msg="Failed to get ipvs modules";      
				alarm_monitors($warn_msg, 1);                                                            
			} 
		}
		elsif($res)
		{
			if($check_ipvs_number == -7)       
			{    
				$check_ipvs_number = 0;       
				$warn_msg="sucess to get ipvs modules";          
				alarm_monitors($warn_msg, 1);    
			}
			if($flag and defined($tmp_info{"ipvs_loaded"}) and ($tmp_info{"ipvs_loaded"} eq "BAD"))
			{
				$warn_msg = "ip_vs/ip_vs_wrr is all loaded !";
				alarm_monitors($warn_msg, 1);
			}
			$tmp_info{"ipvs_loaded"} = "OK";
		}
		else
		{
			if($check_ipvs_number == -7)
			{
				$check_ipvs_number = 0; 
				$warn_msg="sucess to get ipvs modules";                        
				alarm_monitors($warn_msg, 1);
			}
			if(($flag and defined($tmp_info{"ipvs_loaded"}) and ($tmp_info{"ipvs_loaded"} eq "OK")) or ($flag == 0) or $ip_vs_check_time < 3)
			{
				$warn_msg = "ip_vs/ip_vs_rr is not loaded!";
				alarm_monitors($warn_msg, 1);
				$ip_vs_check_time++;
			}
			$tmp_info{"ipvs_loaded"} = "BAD";
## no lvs loaded, nothing to do next.
			next;
		}


#check CPU soft>threshold
		$retry = $retry_number;
		$res = check_cpu_soft($retry);    
		if( $res == -7 )
		{
			if($cpu_idle_number != -7)
			{
				$cpu_idle_number = -7;
				$warn_msg="Failed to get cpu idle";
				alarm_monitors($warn_msg, 1);
			}
		}
		elsif($res)
		{
			if($cpu_idle_number == -7)
			{
				$cpu_idle_number = 0;
				$warn_msg="sucess to get cpu idle";
				alarm_monitors($warn_msg, 1);
			}
			if($flag and defined($tmp_info{"cpu_soft"}) and ($tmp_info{"cpu_soft"} eq "BAD"))
			{ 
				$warn_msg = "cpu_soft < ".ratio_format($cpu_soft)."!";
				alarm_monitors($warn_msg, 1);
			}
			$tmp_info{"cpu_soft"} = "OK";
		}
		else
		{
			if($cpu_idle_number == -7)
			{
				$cpu_idle_number = 0;
				$warn_msg="sucess to get cpu soft";
				alarm_monitors($warn_msg, 1);
			}
			if(($flag and defined($tmp_info{"cpu_soft"}) and ($tmp_info{"cpu_soft"} eq "OK")) or ($flag == 0))
			{
				$warn_msg = "$cpu_data,soft>".ratio_format($cpu_soft)."!";
				print "message: $warn_msg\n";
				alarm_monitors($warn_msg, 1);
			}
			$tmp_info{"cpu_soft"} = "BAD";
		}

#check memory free > total-threshold
		$retry = $retry_number;
		$res = check_memory_free($retry);
		if( $res == -7 )
		{
			if($memory_free_number != -7)
			{
				$memory_free_number = -7;
				$warn_msg="Failed to get memory free";
				alarm_monitors($warn_msg, 1);
			}
		}
		elsif($res)
		{
			if($memory_free_number == -7)
			{
				$memory_free_number = 0;
				$warn_msg="sucess to get memory free";
				alarm_monitors($warn_msg, 1);
			}
			if($flag and defined($tmp_info{"memory_free"}) and ($tmp_info{"memory_free"} eq "BAD"))
			{ 
				$warn_msg = "mem_used < ".ratio_format($memory_used)."!";
				alarm_monitors($warn_msg, 1);
			}
			$tmp_info{"memory_free"} = "OK";
		}
		else
		{
			#print "tmp_info: ";
			#print $tmp_info{"memory_free"};
			#print "\n";
				
			if($memory_free_number == -7)
			{
				$memory_free_number = 0;
				$warn_msg="sucess to get memory free";
				alarm_monitors($warn_msg, 1);
			}
			if(($flag and defined($tmp_info{"memory_free"}) and ($tmp_info{"memory_free"} eq "OK")) or ($flag == 0))
			{
				$warn_msg = "mem_used = ".ratio_format($memory_data).", > ".ratio_format($memory_used)."!";
				alarm_monitors($warn_msg, 1);
			}
			$tmp_info{"memory_free"} = "BAD";
		}


# check disk used
		$retry = $retry_number;
		$res = check_disk_used($retry);
		if( $res == -7 )
		{
			if($disk_used_number != -7)
			{
				$disk_used_number = -7;
				$warn_msg="Failed to get disk info";
				alarm_monitors($warn_msg, 1);
			}
		}
		elsif($res)
		{
			if($disk_used_number == -7)
			{
				$disk_used_number = 0;
				$warn_msg="success to get disk info";
				alarm_monitors($warn_msg, 1);
			}
			if($flag and defined($tmp_info{"disk_used"}) and ($tmp_info{"disk_used"} eq "BAD"))
			{ 
				$warn_msg = "disk_used < ".ratio_format($disk_used_rate)."!";
				alarm_monitors($warn_msg, 1);
			}
			$tmp_info{"disk_used"} = "OK";
		}
		else
		{
			if($disk_used_number == -7)
			{
				$disk_used_number = 0;
				$warn_msg="success to get disk info";
				alarm_monitors($warn_msg, 1);
			}
			if(($flag and defined($tmp_info{"disk_used"}) and ($tmp_info{"disk_used"} eq "OK")) or ($flag == 0))
			{
				$warn_msg = "disk ".$disk_on." used = ".ratio_format($disk_used_data).", > ".ratio_format($disk_used_rate)."!";
				alarm_monitors($warn_msg, 1);
			}
			$tmp_info{"disk_used"} = "BAD";
		}


## check ospfd, zebra, keepalived when you can ssh to it.
		foreach my $proc (keys %processes)
		{
			$retry = $retry_number;
			$res = check_process($proc,$retry);
			if($res == -7)
			{
				if($do_alarm_flag{$proc} != -7 or $proc_check_time < 3)
				{
					$do_alarm_flag{$proc} = -7;
					$warn_msg="Failed to get $proc num";
					alarm_monitors($warn_msg, 1);
					$proc_check_time++;
				}
			}
			elsif($res == $processes{$proc})
			{
				if($do_alarm_flag{$proc} == -7)
				{
					$do_alarm_flag{$proc} = 0;
					$warn_msg="success to get $proc num";
					alarm_monitors($warn_msg, 1);
				}
				if($flag and defined($tmp_info{$proc}) and ($tmp_info{$proc} != $processes{$proc}))
				{
					$warn_msg = "get processes num ok: $res";
					alarm_monitors($warn_msg, 1);
				}
				$tmp_info{$proc} = $res;
				$retry = $retry_number;
#healthcheck($retry);
			}
			elsif($res != $processes{$proc})
			{
			#	if($check_process_number == -7)
			#	{
			#		$check_process_number = 0;
			#		$warn_msg="success to get processes num";
			#		alarm_monitors($warn_msg, 1);
			#	}
				if($flag and defined($tmp_info{$proc}) and ($res != $tmp_info{$proc}))
				{
					$warn_msg = "$proc num: $res, expect: $processes{$proc}";
					alarm_monitors($warn_msg, 1);
				}
				elsif($flag == 0)
				{
					$warn_msg = "$proc num: $res, expect: $processes{$proc}";
					alarm_monitors($warn_msg, 1);
				}
				$tmp_info{$proc} = $res;
			}

		}

# check down service
		check_down_service();
	    
# check state change
		$retry = $retry_number;
		check_STATE_change($flag,$retry);

# check hardware
		$retry = $retry_number;
		check_hardware($flag,$retry);

# check ethx state
		$retry = $retry_number;
		check_eth_up($flag,$retry);
# check traffic on nic
		check_traffic2($flag);

# check network
		check_network();

## Check default gw changed or not 
		$retry = $retry_number;
		$res = default_gw_changed($retry);        
		if($flag)
		{
			if($res eq "0.0.0.0")
			{
				if( $default_gw_number != -7 )
				{
					$default_gw_number = -7;
					$warn_msg="Failed to get route";
					alarm_monitors($warn_msg, 1);
				}
			}
			else
			{
				if($default_gw_number == -7)
				{
					$default_gw_number = 0;
					$warn_msg="success to get route";
					alarm_monitors($warn_msg, 1);
				}
				if(defined($tmp_info{"default_gw"}) and $tmp_info{"default_gw"} ne $res)
				{
					$warn_msg = "df gw changed from \($tmp_info{\"default_gw\"}\) to \($res\)!";
					alarm_monitors($warn_msg, 1);
				}
				$tmp_info{"default_gw"} = $res;
			}
		}
		else
		{
			$tmp_info{"default_gw"} = $res;
		}

####monitore the keepalivde processes respwan
		diff_process_pid($flag);
	}
}

# Initialize the servers status
sub initial_servers()
{
	$date = `/bin/date +%c`;
	chomp($date);
	print "$date: LVS Service Monitor Started!\n";
	check_all_servers(0);
}

sub initial_traffic()
{
    my $tmp  = `/sbin/ifconfig | grep "eth" | awk '{print \$1}' | tr '\n' ' '`;
    my @nic_list = split(/ /, $tmp);
    for my $nic (@nic_list) {
	chomp $nic;
	my $speed = `/sbin/ethtool $nic | grep Speed | awk '{print \$2}'`;
	if ($speed =~ /10000Mb\/s/) {
	    $nic_alarm_table{"$nic"}[0] = 1;
	    $nic_alarm_table{"$nic"}[1] = 0;
	} else {
	    $nic_alarm_table{"$nic"}[0] = 0;
	    $nic_alarm_table{"$nic"}[1] = 0;
	}
    }
}

#################
# Main Process
#################
if(not defined $ARGV[0] or not -f $ARGV[0] or not defined $ARGV[1] or not -f $ARGV[1])
{
	usage();
	exit(1);
}

if ( ! -e $down_vs_list) {
    `touch $down_vs_list`;
};

get_config($ARGV[0]);

#get_alarm_service($ARGV[1]);

print_conf();

initial_servers();
initial_traffic();

while(1)
{
	get_alarm_service($ARGV[1]);
	check_all_servers(1);
	sleep($interval_time);
}
