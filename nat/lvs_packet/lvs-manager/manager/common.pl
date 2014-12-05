use strict;
###############
# Const Values
###############
## true and false, success and fail
use constant true => 1;
use constant TRUE => 1;
use constant false => 0;
use constant FALSE =>0;

## Valid protocol
my @Protocol = ('TCP', 'UDP');
## Valid keepalived process
my @keepalived_process = ("all", "vrrp", "checker");
## Checkers
my @Checkers = ('TCP_CHECK', 'HTTP_GET', 'SSL_GET', 'MISC_CHECK');

##################
# Basic functions
##################
sub lock_bvs
{
	`mkdir ./lock`;
	if($? ne 0)
	{
		return false;
	}
	return true;
}

sub unlock_bvs
{
	`rm ./lock -rf`;
}
# print error message and exit with exit code
# $_[0] error message
# $_[1] exit code
sub err_exit($$)
{
	print "$_[0]\n";
	unlock_bvs();
	exit $_[1];
}

# print usage info and quit
# $_[0] program name
sub usage($)
{
	my $uls = "\e[4m";
	my $ule = "\e[0m";
	print("Usage: $0 [command] [[option]=[value]]\n");
	print("${uls}options$ule underlined are indispensable.\n");
	print("  add_sv|del_sv           ${uls}service_name=[service name]$ule\n");
	print("  add_vs|edit_vs          ${uls}vip=[vip] vport=[vport]$ule protocol=[protocol]\n");
	print("                          ${uls}service_name=[service name]$ule [vs config]=[value]\n");
	print("  add_vrrp|edit_vrrp      ${uls}vrrp_name=[vrrp name]$ule vrrp_instance=[instance name]\n");
	print("                          ${uls}virtual_router_id=[router id]$ule state=[state] priority=[priority]\n");
	print("                          ${uls}vip=[vip]$ule interface=[dev name]\n");
	print("  del_vrrp                ${uls}vip=[vip]\n");
	print("  del_vs                  ${uls}vip=[vip] vport=[vport]$ule protocol=[protocol]\n");
	print("                          ${uls}service_name=[service name]$ule\n");
	print("  add_rs                  ${uls}vip=[vip] vport=[vport]$ule protocol=[protocol]\n");
	print("                          ${uls}service_name=[service name] rip=[rip] rport=[rport]$ule\n");
	print("                          checker=[checker] [rs config]=[value]\n");
	print("  del_rs                  ${uls}vip=[vip] vport=[vport]$ule protocol=[protocol]\n");
	print("                          ${uls}service_name=[service name] rip=[rip] rport=[rport]$ule\n");
	print("  add_bip                 ${uls}vip=[vip] vport=[vport]$ule protocol=[protocol]\n");
	print("                          ${uls}service_name=[service name] bip=[rip] dev=[dev] mask=[mask]$ule\n");
	print("  del_bip                 ${uls}vip=[vip] vport=[vport]$ule protocol=[protocol]\n");
	print("                          ${uls}service_name=[service name] bip=[rip]$ule\n");
	print("  add_static_ip           ${uls}static_ip=[static ip]$ule dev=[dev name] mask=[net mask]\n");
	print("  del_static_ip           ${uls}static_ip=[static ip]\n");
	print("  get_static_ip\n");    
	print("  lvs_alarm               ${uls}alarm=[start|stop]\n");
	print("  enable_vip|disable_vip  ${uls}vip=[vip]$ule\n");
	print("  reload_keepalived       process=[process]\n");
	print("  get_conf_all_sv\n");
	print("  get_conf_sv             ${uls}service_name=[service name]$ule\n");
	print("  get_conf_vs             ${uls}vip=[vip] vport=[vport]$ule protocol=[protocol]\n");
	print("  get_conf_rs             ${uls}vip=[vip] vport=[vport]$ule protocol=[protocol]\n");
	print("                          ${uls}service_name=[service name]$ule\n");
	print("  get_conf_bip            ${uls}vip=[vip] vport=[vport]$ule protocol=[protocol]\n");
	print("                          ${uls}service_name=[service name]$ule\n");
	print("  get_bvs_vs\n");
	print("  get_bvs_rs              ${uls}vip=[vip] vport=[vport]$ule protocol=[protocol]\n");
	print("  get_bvs_bip             ${uls}vip=[vip] vport=[vport]$ule protocol=[protocol]\n");
	print("  upload_config\n");
	print("  download_config\n");
	print("  backup_config\n");
	print("  remote_backup_config\n");
	print("  add_alarm               ${uls}vip=[vip] virtualhost=[virtualhost] sms_alarm=[sms_alarm] email_alarm=[email_alarm]\n");
	print("  del_alarm               ${uls}vip=[vip]\n");
	print("\n");

	print("Commands:\n");
	print("  add_sv              Add a service\n");
	print("  del_sv              Delete a service\n");
	print("  add_vs              Add a virtual server\n");
	print("  del_vs              Delete a virtual server\n");
	print("  edit_vs             Modify config of a virtual server\n");
	print("  add_vrrp	     add vrrp instance\n");
	print("  edit_vrrp	     edit vrrp instance\n");
	print("  del_vrrp	     del vrrp instance\n");
	print("  add_static_ip	     add static ip to keepalived.conf\n");
	print("  del_static_ip	     del static ip to keepalived.conf\n");
	print("  get_static_ip	     get static ip to keepalived.conf\n");
	print("  lvs_alarm	     lvs_alarm operation\n");
	print("  add_rs              Add a real server to a virtual server\n");
	print("  del_rs              Delete a real server from a virtual server\n");
	print("  add_bip             Add a backend ip to a virtual server\n");
	print("  del_bip             Delete a backend ip from a virtual server\n");
	print("  enable_vip          Enable a vip on bvs, i.e. bind a vip to lo and modify\n");
	print("                      /etc/rc.local\n");
	print("  disable_vip         Disable a vip on bvs, i.e. delete a vip from lo and\n");
	print("                      modify /etc/rc.local\n");
	print("  reload_keepalived   Reload keepalived process on bvs, i.e. send HUP signal\n");
	print("                      to keepalived process\n");
	print("  get_conf_all_sv     List all services in current bvs config file\n");
	print("  get_conf_sv         List all virtual servers of a service in current bvs\n");
	print("                      config file\n");
	print("  get_conf_vs         List configuration of a virtual service in current bvs\n");
	print("                      config file\n");
	print("  get_conf_rs         List all real servers of a virtual server in current \n");
	print("                      bvs config file\n");
	print("  get_conf_bip        List all backend ip addresses of a virtual server in\n");
	print("                      current bvs config file\n");
	print("  get_bvs_vs          List all virtual servers on bvs\n");
	print("  get_bvs_rs          List all real servers of a virtual server on bvs\n");
	print("  get_bvs_bip         List all backend ip addresses of a virtual server on bvs\n");
	print("  upload_config       Upload config files to bvs\n");
	print("  download_config     Download config files from bvs\n");
	print("  backup_config       Backup current config files\n");
	print("  remote_backup_config       Backup remote config files\n");
	print("\n");
	print("Options:\n");
	print("  Services Related:\n");
	print("  service_name   name of a service\n");
	print("  Virtual Server Related:\n");
	print("  vip            IP of virtual server\n");
	print("  vport          Port of virtual server\n");
	print("  protocol       Protocol of virtual server, TCP or UDP. It's TCP by default.\n");
	print("  Real Server Related:\n");
	print("  rip           IP of real server\n");
	print("  rport         Port of real server\n");
	print("  checker        Kind of checker to use, TCP_CHECK, HTTP_GET, MISC_CHECK. It\n");
	print("                 also can be NO_CHECK, which means this real server has no checker.\n");
	print("                 NO_CHECK is the default value if checker not given.\n");
	print("  Backend IP Related:\n");
	print("  bip            Backend IP of a virtual server\n");
	print("  dev            which device should be used to bind bip\n");
	print("  mask           which mask should be used when bind bip, it shoud be in [1-32]\n");
	print("\n");
	exit(0);
}


# return true if $_[0] is an ip address
sub is_ip($)
{
    if("$_[0]" =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
        if($1 >= 0 && $1 <= 255 && $2 >= 0 && $2 <= 255 && $3 >= 0 && $3 <= 255 && $4 >= 0 && $4 <= 255) {
            return true;
        }
    }
    return false;
}

sub is_net_mask($)
{
    if ($_[0] gt 0 and $_[0] lt 32) {
	return true;
    }
    return false;
}

sub is_string($)
{
	if($_[0] =~ /\s+/)
	{
		return false;
	}
	return true;
}
# is $_[0] a port number? 1-65535
sub is_port($)
{
	if("$_[0]" =~ /^(\d+)$/) {
		if($1 > 0 && $1 < 65535) {
			return true;
        	}
    	}
	return false;
}
sub is_ports($)
{
        my $port;
        my $ret;
        my @info = split /:/,$_[0];
        foreach $port (@info){
                $ret=is_port($port);
                if(false == $ret){
                        return false;
                }
        }
        return true;

}
sub is_num ($)
{

        if("$_[0]" =~ /^(\d+)$/) {
                return true;
        }
        return false;
}
sub is_status_code($)
{
        if("$_[0]" =~ /^(\d+)$/ or "$_[0]" eq "") {
        	return true;
        }
        return false;
}
# is $_[0] a valid protocol?
sub is_protocol($)
{
	foreach my $pro (@Protocol)
	{
		if($pro eq $_[0])
		{
			return true;
		}
	}
	return false;
}

# is $_[0] a valid keepalived process?
sub is_keepalived_process($)
{
	foreach my $pro (@keepalived_process)
	{
		if($pro eq $_[0])
		{
			return true;
		}
	}
	return false;

}

# is it a good service name?
sub is_service_name($)
{
	if($_[0] =~ /^[a-zA-Z0-9\-\_\.]+$/)
	{
		return true;
	}
	return false;
}

# is it a unsigned int?
sub is_uns_int($)
{
	if($_[0] =~ /^\d+$/)
	{
		return true;
	}
	return false;
}

sub is_mask($)
{
	if($_[0] =~ /^(\d+)$/)
	{
		if($1 > 0 and $1 <= 32)
		{
			return true;
		}
	}
	return false;
}

# is it a num 0 or 1, not other value?
sub is_zero_one($)
{
	if($_[0] eq '0' or $_[0] eq '1')
	{
		return true;
	}
	return false;
}

# is it a valid load balance module name? rr only now.
sub is_lb_algo($)
{
        if($_[0] eq "rr" or $_[0] eq "L7" or
           $_[0] eq "wrr" or $_[0] eq "hh" or 
	   $_[0] eq "srch")
	{
		return true;
	}
	return false;
}

sub is_pattern($)
{
	return true;
}

sub is_virtualhost($)
{
	return true;
}
sub is_vgrpname($)
{
    return true;
}
# is it a valid load balance kind? NAT only now.
sub is_lb_kind($)
{
	if($_[0] eq "NAT" or $_[0] eq "DR")
	{
		return true;
	}
	return false;
}

# is it a ration 0 < $_[0] < 100?
sub is_ratio($)
{
	my $ratio = $_[0];
	if($_[0] =~ /^(\d+)$/)
	{
		if($1 >= 0 and $1 <= 100)
		{
			return true;
		}
	}
	return false;
}

# is it a checker?
sub is_checker($)
{
	foreach my $ch (@Checkers)
	{
		if($ch eq $_[0])
		{
			return true;
		}
	}
	return false;
}

sub is_dev($)
{
	if($_[0] =~ /^eth\d+.*$/ or $_[0] =~ /^null/)
	{
		return true;
	}
	return false;
}

sub get_localtime
{	
	my $date;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon ++;
	$date = sprintf("%04d.%02d.%02d.%02d.%02d.%02d", $year, $mon, $mday, $hour, $min, $sec);
	return $date;
}

# cp file to file.time, e.g. file.2012.03.22.21.11.01
# $_[0] source path of file or directory
# $_[1] dest path
# return
sub back_up_file($$)
{
	my $date;
	my $result;
	my $file_name;
	$date = get_localtime();
	my @tmp = split('/', $_[0]);
	if (-d $_[0] or -f $_[0])
	{
		$file_name = $tmp[$#tmp];
		chomp($file_name);
	}
	else
	{
		return -1;
	}

	if (not -e $_[1])
	{
		print("mkdir -p $_[1]\n");
		`mkdir -p $_[1]`;
	}

	if( -e "$_[1]/$file_name.$date")
	{
		my $i = 2;
		while( -e "$_[1]/$file_name.$date.$i")
		{
			$i++;
		}
		$date .= ".$i";
	}

	print("backup $_[0] to $_[1]/$file_name.$date\n");
	$result = `cp -r $_[0] $_[1]/$file_name.$date`;
	if ($? != 0 or $result ne "")
	{
		return 1;
	}
	if (-d "$_[1]/$file_name.$date/lock")
	{
		rmdir("$_[1]/$file_name.$date/lock");
	}
	return 0;
}

sub is_vrrp_name($)
{
    if ( "$_[0]" =~ /^VI_[a-zA-Z0-9_]+$/) {
	print "is_vrrp_name: return true: $_[0]\n";
	return true;
    }
    print "is_vrrp_name: return false: $_[0]\n";
    return false;
}

sub is_vrrp_router_id($)
{
    if ("$_[0]" =~ /^[0-9\-\_\.]+$/) {
	print "is_vrrp_router_id: return true\n";
	return true;
    }
    print "is_vrrp_router_id: return false\n";
    return false;
}

sub is_vrrp_stat($)
{
    if ("$_[0]" == "MASTER" or "$_[0]" == "BACKUP") {
	print "is_vrrp_stat: return true\n";
	return true;
    }
    print "is_vrrp_stat: return false\n";
    return false;
}

sub is_vrrp_priority($)
{
    if ($_[0] == 110 or $_[0] == 90) {
	print "is_vrrp_priority: true\n";
	return true;
    }
    print "is_vrrp_priority: false\n";
    return false;
}

sub is_if_name($)
{
    if ("$_[0]" =~ /^eth\d+.*$/ or "$_[0]" =~ /^vlan\d+.*$/) {
	print "is_if_name: true\n";
	return true;
    }
    print "is_if_name: false: $_[0]\n";
    return false;
}

sub is_brd($)
{
    return is_ip($_[0]);
}

1;
