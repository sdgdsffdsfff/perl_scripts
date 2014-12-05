#!/usr/bin/perl
# $Description: A script to monitor lvs cluster. If there is something wrong with , it sends warning messages to monitors.

use File::Basename;
$MAIN_DIR=dirname($0);
require ($MAIN_DIR."/report.pl");

use LWP;
use strict; 
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

my $cpu_idle = 0.5; 
my $memory_used = 8000000;
my $disk_used_rate = 0.8;

my $retry_number = 0;
my $retry;

my $check_process_number = 0;
my $check_ipvs_number = 0;
my $check_healthcheck_number = 0;
my $cpu_idle_number = 0;
my $memory_free_number = 0;
my $disk_used_number = 0;
my $get_eth_up_number = 0;
my $get_STATE_change_number = 0;
my $default_gw_number = 0;
#healthcheck
my %healthcheck_none = ();
my %healthcheck_state = ();
my %healthcheck_numbers = ();
my $nohealthcheck_times = 7 ;

my $cpu_data = 0;
my $memory_data = 0;
my $disk_used_data = 0;
my $disk_on = 0;

my $gsms="lvs_tcpdns_bjt";
my $gemail="";

# gsmsend/mail to monitors
# FIXME: mail support
sub alarm_monitors($$)
{
	$date = `date +%c`;
	$warn_msg = $_[0];

	chomp($date);
	print "$date: $warn_msg\n";
	&doAlarm($warn_msg, $warn_msg, $_[1]);
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

# check whether the process is running on the server. this is used to check zebra, ospfd, keepalived
# param $_[0] process name
# param $_[1] retry time 
# return number of processes running on the machine, -1 means failed to get.
sub check_process($$)
{
    do
    {
        my $sshcmd = "pidof -x $_[0]";
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

# check whether the ip_vs module is loaded
sub check_ip_vs_loaded($)
{
	do
	{
		my $chkcmd = "lsmod";
		my @res = `$chkcmd 2>/dev/null 0</dev/null`;
		if( $? == 0 )
		{
			my $i = 0;
			chomp(@res);
			foreach my $line (@res)
			{
				if($line =~ /^\s*(\bip_vs\b|\bip_vs_wrr\b)/)
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
		my $ipvscmd = "ipvsadm -ln";
		my @res = `$ipvscmd 2>/dev/null 0</dev/null`;
		if($? == 0)
		{
			if($check_healthcheck_number == -7)
			{
				$check_healthcheck_number = 0;
				$warn_msg="It is sucessful to get number of healthcheck numbers";
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
						$warn_msg="keepalived:  vip $vip_rs has not been done!";
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
			$warn_msg="Failed to get number of healthcheck numbers";
			alarm_monitors($warn_msg, 1);
		}
	}
}

# check whether the cpu_idle>threshold
sub check_cpu_idle($)
{
	do
	{
		my $chkcmd = "mpstat -P ALL 1 1";
		my @res = `$chkcmd 2>/dev/null 0</dev/null`;
		if( $? == 0 )
		{
			chomp(@res);
			my $flagmatch = 0;
			foreach my $line (@res)
			{
				if ($line =~ /Average:\s+[0-9]+\s+([0-9\.]+\s+){3}([0-9\.]+)\s+([0-9\.]+\s+){3}([0-9\.]+)\s+[0-9\.]/)
				{
					my $iowait = $2;
					my $on_idle = $4;
					my $idle = ($on_idle+$iowait)/100;
					if($idle < $cpu_idle )
					{
						$cpu_data = "cpu idle is ".$on_idle." , and  iowait is ".$iowait ;
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
	do
	{
		my $chkcmd = "free";
		my $res = `$chkcmd 2>/dev/null 0</dev/null`;
		if( $? == 0 )
		{
			my $tmp;
			chomp($res);
			if($res =~ /-\/\+[\s\t]+buffers\/cache:[\s\t]+([0-9]+)[\s\t]+([0-9]+)/s)
			{
				if($2 < (($2+$1)-$memory_used))
				{
					$memory_data = $2 ;
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
		my $chkcmd = "df";
		my @res = `$chkcmd 2>/dev/null 0</dev/null`;
		if( $? == 0 )
		{
			chomp(@res);
			my $flagmatch = 0;
			foreach my $line (@res)
			{
				if($line =~ /^\/dev\/[\w\/]+\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+([0-9]+)\%\s+([\/\w]+)$/)
				{	
					my $rate = $1/100;
					$disk_on = $2;
					if( $rate > $disk_used_rate)
					{
						$disk_used_data = "disk mounted on ".$disk_on." have been used ".$rate;
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
			$chkcmd = "dmesg >> /var/log/dmesg.bak ;dmesg -c > /dev/null";
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
			$warn_msg="Failed to clean  dmesg away";
			alarm_monitors($warn_msg, 1);
		}
	}
	else
	{ 
		do
		{
			$chkcmd = "dmesg";
			@array = `$chkcmd 2>/dev/null 0</dev/null`;
			if( $? == 0 )
			{
				if($get_eth_up_number == -7)
				{
					$get_eth_up_number = 0;
					$warn_msg="It is successful to get data of dmesg";
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
					}
				}
				if($cflag == 0 and $#array > 1000)
				{
					$chkcmd = "dmesg >> /var/log/dmesg.bak ;dmesg -c > /dev/null";
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
				$warn_msg="Failed to get data of dmesg";
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
			$warn_msg="Failed to clean  /var/log/messages away";                   
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
					$warn_msg="$_[0]: It is successful to get data of /var/log/messages";                                     
					alarm_monitors($warn_msg, 1);                                                                    
				}
				chomp(@array);
				foreach my $line (@array)
				{
					my $found=0;
					if($line =~ /.*?Keepalived_vrrp: VRRP_Instance\((.*?)\)\s(Entering\s[A-Z]*?\sSTATE)/ )
					{
						$warn_msg="$1:$2!";
						alarm_monitors($warn_msg, 1);
						$found = 1;
					} elsif ($line =~ /.*?Keepalived_healthcheckers: Disabling service (\[.*?\])\sfrom VS\s(\[.*?\])/ ) {
						$warn_msg="RS $1 for VS $2, health checker FAILED!";
						alarm_monitors($warn_msg, 0);
						$found = 1;
					} elsif ($line =~ /.*?Keepalived_healthcheckers: Removing service (\[.*?\])\sfrom VS\s(\[.*?\])/ ) {
						$warn_msg="RS $1 for VS $2, health checker FAILED!";
						alarm_monitors($warn_msg, 0);
						$found = 1;
					} elsif ($line =~ /.*?Keepalived_healthcheckers: Enabling service (\[.*?\])\sto VS\s(\[.*?\])/ ) {
						$warn_msg="RS $1 for VS $2, health checker SUCCESS!";
						alarm_monitors($warn_msg, 0);
						$found = 1;
					} elsif ($line =~ /.*?Keepalived_healthcheckers: Adding service (\[.*?\])\sto VS\s(\[.*?\])/ ) {
						$warn_msg="RS $1 for VS $2, health checker SUCCESS!";
						alarm_monitors($warn_msg, 0);
						$found = 1;
					} elsif ($line =~ /.*?Keepalived_healthcheckers: VS (\[.*?\])\srs_alive_ratio \(.*?%\) <= rs_alive_ratio_down \(.*?%\), notify the vrrp instance to decrease priority./ ) {
						$warn_msg="VS $1 is DOWN!";
						alarm_monitors($warn_msg, 1);
						$found = 1;
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
				$warn_msg="Failed to get data of /var/log/messages";
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
		my $chkcmd = "route -n";
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

# get the configurations
sub get_config($)
{
	my $all_lines;
	my $threshold ;
	open CONF_FILE, "<$_[0]" or die("Could not open configure file!\n");
	while(<CONF_FILE>)
	{
		if(/threshold\{/../\}/)
		{
			if($_ =~ /^\s*cpu_idle\s*\=\s*([0-9\.]+)\s*;/)
			{
				$threshold = $1 ;
				if( $threshold =~ /^[0-9]*(\.)?[0-9]+$/ )
				{
					$cpu_idle = $threshold;
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
		}
		elsif(/healthcheck\{/../\}/)
		{
			if($_ =~ /^\s*nohealthcheck_times\s*\=\s*([0-9]+)\s*;/)
			{
				$nohealthcheck_times = $1;
			}
		}
		elsif(/time\{/../\}/)
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
		elsif(/processes\{/../\}/)
		{
			if($_ =~/^\s*([\w\-]+)\s*\=\s*([0-9]+)\s*;/)
			{
				$processes{$1} = $2;
			}
		}
		else
		{	
			print "unknow cmd";
		}
	}
    
	print "\nProcesses:\n";
	foreach my $key (keys %processes )
	{
		print "$key: $processes{$key}\n";
	}
	print "Interval_time:$interval_time\n";
	print "retry_number:$retry_number\n";
	print "cpu_idle_threshold:$cpu_idle\n";
	print "memory_used_threshold:$memory_used\n";	
	print "disk_used_rate_threshold:$disk_used_rate\n";
	print "nohealthcheck_times:$nohealthcheck_times\n";
	
	close CONF_FILE;
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
				$warn_msg="Failed to get the number of ipvs modles";      
				alarm_monitors($warn_msg, 1);                                                            
			} 
		}
		elsif($res)
		{
			if($check_ipvs_number == -7)       
			{    
				$check_ipvs_number = 0;       
				$warn_msg="It is sucessful to get the number of ipvs modles";          
				alarm_monitors($warn_msg, 1);    
			}
			if($flag and defined($tmp_info{"ipvs_loaded"}) and ($tmp_info{"ipvs_loaded"} eq "BAD"))
			{
				$warn_msg = "ip_vs and ip_vs_rr is all loaded !";
				alarm_monitors($warn_msg, 1);
			}
			$tmp_info{"ipvs_loaded"} = "OK";
		}
		else
		{
			if($check_ipvs_number == -7)
			{
				$check_ipvs_number = 0; 
				$warn_msg="It is sucessful to get the number of ipvs modles";                        
				alarm_monitors($warn_msg, 1);
			}
			if(($flag and defined($tmp_info{"ipvs_loaded"}) and ($tmp_info{"ipvs_loaded"} eq "OK")) or ($flag == 0))
			{
				$warn_msg = "ip_vs or ip_vs_rr is NOT properly loaded!";
				alarm_monitors($warn_msg, 1);
			}
			$tmp_info{"ipvs_loaded"} = "BAD";
			## no lvs loaded, nothing to do next.
			next;
		}


		#check CPU idle>threshold
                $retry = $retry_number;
                $res = check_cpu_idle($retry);    
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
				$warn_msg="It is sucessful to get cpu idle";
				alarm_monitors($warn_msg, 1);
			}
			if($flag and defined($tmp_info{"cpu_idle"}) and ($tmp_info{"cpu_idle"} eq "BAD"))
			{ 
				$warn_msg = "cpu_idle > $cpu_idle !";
				alarm_monitors($warn_msg, 1);
			}
			$tmp_info{"cpu_idle"} = "OK";
		}
		else
		{
			if($cpu_idle_number == -7)
			{
				$cpu_idle_number = 0;
				$warn_msg="It is sucessful to get cpu idle";
				alarm_monitors($warn_msg, 1);
			}
			if(($flag and defined($tmp_info{"cpu_idle"}) and ($tmp_info{"cpu_idle"} eq "OK")) or ($flag == 0))
			{
				$warn_msg = "cpu_idle < $cpu_idle !$cpu_data .";
				alarm_monitors($warn_msg, 1);
			}
			$tmp_info{"cpu_idle"} = "BAD";
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
				$warn_msg="It is sucessful to get memory free";
				alarm_monitors($warn_msg, 1);
			}
			if($flag and defined($tmp_info{"memory_free"}) and ($tmp_info{"memory_free"} eq "BAD"))
			{ 
				$warn_msg = "memory_used < $memory_used !";
				alarm_monitors($warn_msg, 1);
			}
			$tmp_info{"memory_free"} = "OK";
		}
		else
		{
			if($memory_free_number == -7)
			{
				$memory_free_number = 0;
				$warn_msg="It is sucessful to get memory free";
				alarm_monitors($warn_msg, 1);
			}
			if(($flag and defined($tmp_info{"memory_free"}) and ($tmp_info{"memory_free"} eq "OK")) or ($flag == 0))
			{
				$warn_msg = "memory_used > $memory_used !memory_used is $memory_data .";
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
				$warn_msg="Failed to get the used situation of disk";
				alarm_monitors($warn_msg, 1);
			}
		}
		elsif($res)
		{
			if($disk_used_number == -7)
			{
				$disk_used_number = 0;
				$warn_msg="It is sucessful to get the used situation of disk";
				alarm_monitors($warn_msg, 1);
			}
			if($flag and defined($tmp_info{"disk_used"}) and ($tmp_info{"disk_used"} eq "BAD"))
			{ 
				$warn_msg = "disk_used rate < $disk_used_rate !";
				alarm_monitors($warn_msg, 1);
			}
			$tmp_info{"disk_used"} = "OK";
		}
		else
		{
			if($disk_used_number == -7)
			{
				$disk_used_number = 0;
				$warn_msg="It is sucessful to get the used situation of disk";
				alarm_monitors($warn_msg, 1);
			}
			if(($flag and defined($tmp_info{"disk_used"}) and ($tmp_info{"disk_used"} eq "OK")) or ($flag == 0))
			{
				$warn_msg = "disk_used rate > $disk_used_rate ! $disk_used_data .";
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
				if($check_process_number != -7)
				{
					$check_process_number = -7;
					$warn_msg="Failed to get number of processes";
					alarm_monitors($warn_msg, 1);
				}
			}
			elsif($res == $processes{$proc})
			{
				if($check_process_number == -7)
				{
					$check_process_number = 0;
					$warn_msg="It is successful to get number of processes";
					alarm_monitors($warn_msg, 1);
				}
				if($flag and defined($tmp_info{$proc}) and ($tmp_info{$proc} != $processes{$proc}))
				{
					$warn_msg = "get number of processes ok: $res";
					alarm_monitors($warn_msg, 1);
				}
				$tmp_info{$proc} = $res;
				$retry = $retry_number;
				#healthcheck($retry);
			}
			elsif($res != $processes{$proc})
			{
				if($check_process_number == -7)
				{
					$check_process_number = 0;
					$warn_msg="It is successful to get number of processes";
					alarm_monitors($warn_msg, 1);
				}
				if($flag and defined($tmp_info{$proc}) and ($res != $tmp_info{$proc}))
				{
					$warn_msg = "$proc: get number of processes error. old: ${$proc} new: $res It should be $processes{$proc}";
					alarm_monitors($warn_msg, 1);
				}
				elsif($flag == 0)
				{
					$warn_msg = "$proc: get number of processes error:$res. It should be $processes{$proc}";
					alarm_monitors($warn_msg, 1);
				}
				$tmp_info{$proc} = $res;
			}

		}

		# check state change
                $retry = $retry_number;
                check_STATE_change($flag,$retry);

		# check ethx state
                $retry = $retry_number;
                check_eth_up($flag,$retry);

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
					$warn_msg="Failed to get data of route";
					alarm_monitors($warn_msg, 1);
				}
			}
			else
			{
				if($default_gw_number == -7)
				{
					$default_gw_number = 0;
					$warn_msg="It is successful to get data of route ";
					alarm_monitors($warn_msg, 1);
				}
				if(defined($tmp_info{"default_gw"}) and $tmp_info{"default_gw"} ne $res)
				{
					$warn_msg = "default gw changed from \($tmp_info{\"default_gw\"}\) to \($res\)!";
					alarm_monitors($warn_msg, 1);
				}
				$tmp_info{"default_gw"} = $res;
			}
		}
		else
		{
			$tmp_info{"default_gw"} = $res;
		}
	}
}

# Initialize the servers status
sub initial_servers()
{
	$date = `date +%c`;
	chomp($date);
	print "$date: LVS Service Monitor Started!\n";
	check_all_servers(0);
}

#################
# Main Process
#################
if(not defined $ARGV[0] or not -f $ARGV[0])
{
	usage();
	exit(1);
}

get_config($ARGV[0]);
initial_servers();

while(1)
{
	check_all_servers(1);
	sleep($interval_time);
}
