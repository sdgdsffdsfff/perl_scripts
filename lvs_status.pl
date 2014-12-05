#!/usr/bin/perl

my $lvs_main_path = "/home/lvs/";
my $ipvsadm_cmd = "/sbin/ipvsadm -ln";
my @remote_servers  = (
#	"http://api.hulk.corp.qihoo.net:8360/ApiLvsManage/rsStatus",
#	"http://smarte.corp.qihoo.net:8360/opslvs/interface/healthStatus.php"
	"http://api.hulk.corp.qihoo.net:8360/ApiLvsManage/healthBatch",
	"http://smarte.corp.qihoo.net:8360/opslvs/interface/healthBatch2.php"
);
my $falcon_url = "http://smarte.corp.qihoo.net:8360/opslvs/interface/healthBatch2.php";
#my $remote_server = "http://api.hulk.corp.qihoo.net:8360/ApiLvsManage/rsStatus";
my $ipvsadm_file = "$lvs_main_path/ipvsadm_info";
my %last_ipvsadm_info = ();
my $log_file = "$lvs_main_path/log/lvs_status.log";
my $try_time=3;

sub get_localtime
{    
    my $date;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon ++; 
    $date = sprintf("%04d/%02d/%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
    return $date;
}

sub write_log($)
{
    my $msg = $_[0];
    my $date = get_localtime();
    open LOGFD, ">>$log_file" or die("Could not log file!\n");
    #print "$msg\n";
    print LOGFD "$date [lvs config] $msg\n";
    close(LOGFD);
}



sub send_msg()
{
    my ($param) = $_[0];
    my $msg = $_[1];
    my $n = 0;
    my $status = 1;

    foreach my $server (@remote_servers) {
	$n = 0;
	$status = 1;
	while ($n < $try_time) {
	    my $cmd = "curl -m 10 -s '$server?type=0&vip=$param->{\"vip\"}&vport=$param->{\"vport\"}&rip=$param->{\"rip\"}&rport=$param->{\"rport\"}&weight=$param->{\"weight\"}'";
	    my $res = `$cmd`;
	    if ($?>>8 == 0) { 
		$status = 0;
		next;
	    }
	    $n++;
	}

	#print "hulk cmd: $cmd\n";

    	if ($status != 0) {
		write_log("Error: $msg status to hulk failed: [$?], $res!");
    	} else {
		write_log("$msg success!");
	}
    }
}

sub send_global_msg($)
{
    my ($param) = $_[0];
    my $n = 0;

    foreach my $server (@remote_servers) {
	$n = 0;
	my $res = "";

	while ($n < $try_time) {
	    my $cmd = "curl -m 10 -s -d \"$param\" \"$server\"";
	    $res = `$cmd`;
	    if ($res =~ /^{\"RESULT\":\"(\d+)\",\"ERROR_MESSAGE\"/) { 
		if ($1 != 0) { 
		    $n++;
		} else {
		    last;
		}
	    } else {
		$n++;
	    }
	}
	if ($n < $try_time) {
	    write_log("send $param to $server success!");
	} else {
	    write_log("send $param to $server failed: $res");
	}
    }
}

sub get_rs_info($)
{
    my $type = $_[0];
    my @lvs_info = `cat $ipvsadm_file`; 
    my $vip;
    my $vport;
    my $rip;
    my $rport;
    my $weight;
    my %rs_info = ();
    my %param = ();
    my $flag = 0;
    my $falcon_param = "";	
  
    foreach my $line (@lvs_info) {
	if ($line =~ /^TCP\s+(\d+).(\d+).(\d+).(\d+):(\d+)\s+/)  {
	    $vip = "$1.$2.$3.$4";
	    $vport = $5;
	} elsif ($line =~ /\s+->\s+(\d+).(\d+).(\d+).(\d+):(\d+)\s+(\w+)\s+(\d+)/) {
	    $rip = "$1.$2.$3.$4";
	    $rport = $5;
	    $weight = $7;

	    if ($type == 0) {
		$last_ipvsadm_info{"$vip:$vport"}{"$rip:$rport"} = "$weight";
	    } else {
		$param{"vip"} = "$vip";
		$param{"vport"} = "$vport";
		$param{"rip"} = "$rip";
		$param{"rport"} = "$rport";
		$param{"weight"} = "$weight";
		if (not defined $last_ipvsadm_info{"$vip:$vport"} or not defined $last_ipvsadm_info{"$vip:$vport"}{"$rip:$rport"}) {
		    my $msg = "add new vs=$vip:$vport, rs=$rip:$rport, weight=$weight";
#		    write_log("add new vs=$vip:$vport, rs=$rip:$rport, weight=$weight");
#		    &send_msg(\%param, $msg);
		    if ($falcon_param ne "") {
		    	$falcon_param = "$falcon_param|0|$vip|$vport|$rip|$rport|$weight\\n";
		    } else {
			$falcon_param = "data=0|$vip|$vport|$rip|$rport|$weight\\n";
		    }
		} else {
		    my $old_weight = $last_ipvsadm_info{"$vip:$vport"}{"$rip:$rport"};
		    if ($weight != $old_weight) { 
			my $msg = "vs=$vip:$vport, rs=$rip:$rport weight change from $old_weight to $weight";
			#write_log("vs=$vip:$vport, rs=$rip:$rport weight change from $old_weight to $weight");
#		    	&send_msg(\%param, $msg);
			if ($falcon_param ne "") {
				$falcon_param = "$falcon_param|0|$vip|$vport|$rip|$rport|$weight\\n";
			} else {
				$falcon_param = "data=0|$vip|$vport|$rip|$rport|$weight\\n";
			}
		    }
		}
	    }
	}
    }
    if ($falcon_param ne "") {
	send_global_msg($falcon_param);
    }
}

sub get_last_rs_info()
{
    get_rs_info(0);
}

sub get_cur_rs_info()
{
    my $res = `$ipvsadm_cmd > $ipvsadm_file`;
    if ($? == 0) {
	get_rs_info(1);
    }
}

sub lock_lvs
{
    `mkdir /home/lvs/lvs_lock`;
    if($? ne 0)
    {    
	return 0;
    }    
    return 1;
}

sub unlock_lvs
{
    `rm /home/lvs/lvs_lock -rf`;
}

if(!lock_lvs())
{
    print("$op_ret_num_msg{'99'}\n");
    exit(1);
}

if (-e "$ipvsadm_file") {
            get_last_rs_info();
}

get_cur_rs_info();
unlock_lvs();


