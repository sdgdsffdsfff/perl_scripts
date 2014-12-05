#!/usr/bin/perl

my $base = `pwd`;
my %old_nic_table = ();
my $nic_rules = "/etc/udev/rules.d/70-persistent-net.rules";
my $nic_info;
my $nic_name;

my $i=0;
my $nic10000_nr = 0;
my $nic1000_nr = 0;
my $ifcfg_conf = "/etc/sysconfig/network-scripts/";
my $nic_nr = `ifconfig -a | grep eth | wc -l`;
my $flag_gw = 0;

my $default_gw = `route -n | grep UG | awk '{print \$2}'`;
chomp($default_gw);
print "$default_gw\n";

## Job1: check the nic status
for ($i; $i < $nic_nr; $i++) {
	$nic_name = "eth$i";
	$nic_info = `ethtool $nic_name`;

	if ($nic_info =~ /10000Mb/) {
		$nic10000_nr ++;
		$old_nic_table{"$nic_name"}[0] = 10000;
	} 
       	if ($nic_info =~ /1000Mb/) {
		$nic1000_nr ++;
		$old_nic_table{"$nic_name"}[0] = 1000;
	} 

	my $nic_mac = `ip addr list $nic_name | grep 'link/ether' | awk '{print \$2}'`;
	my $ip_addr = `ifconfig $nic_name | grep 'inet addr:' | awk '{print \$2}'`;
	my $net_mask = `ifconfig $nic_name | grep 'inet addr:' | awk '{print \$4}'`;
	my $nic_gw = `cat $ifcfg_conf/ifcfg-$nic_name | grep "GATEWAY" | awk -F "=" '{print \$2}'`;

	#print "$nic_gw\n";
	
	my @ip_array = split(/:/, $ip_addr);
	$ip_addr = $ip_array[1];
	my @mask_array = split(/:/, $net_mask);
	$net_mask = $mask_array[1];
	chomp($nic_mac);
	chomp($ip_addr);
	chomp($net_mask);
	chomp($nic_gw);
	if ($nic_gw) {
		#$flag_gw = 1;
		if ($nic_gw ne $default_gw) {
			print "Wrong GateWay: Exist Another GW: $nic_gw, BUT Default is $default_gw\n";
			goto END;
		}
		if ($nic_gw eq $default_gw) {
			$flag_gw = 1;
		}
	} 

	#print "Old MAC: $nic_mac\n$ip_addr\n$net_mask\n";
	
	$old_nic_table{"$nic_name"}[1] = $nic_mac;
	$old_nic_table{"$nic_name"}[2] = $ip_addr;
	$old_nic_table{"$nic_name"}[3] = $net_mask;
	$old_nic_table{"$nic_name"}[4] = $nic_gw;
}

$i=0;
for ($i; $i<$nic_nr; $i++)
{
	my $test = $old_nic_table{"$nic_name"}[4] = $nic_gw;
	if ($test) {
		print "$test\n";
		last;
	}
}

if (($flag_gw ne 1) && ($i eq $nic_nr)) {
	print "$flag_gw\t $i\n";
	print "Gateway config err \n";
	goto END;
}

# Only for 2-10000Mb/2-1000Mb nics OR 4 1000Mb nics
if ($nic10000_nr ne 2) {
	if ($nic1000_nr ne 4) {
		print "10000Mb nic do not exit\n";
		exit(1);
	}
}

chomp($base);
#do backup ifcfg-eth8
my $ifcfg_backup = "$base/ifcfg_backup";
if (-e $ifcfg_backup) {
	`rm -rf $ifcfg_backup`;
}
`mkdir $ifcfg_backup && cp $ifcfg_conf/ifcfg-eth* $ifcfg_backup`;

# Gen new Mac addr
my $new_ifcfg = "$base/new_ifcfg";
if (-e $new_ifcfg) {
	`rm -rf $new_ifcfg`;
}
`mkdir $new_ifcfg`;

$i = 0;
my $flag = 0;
my $interflag = 2;
my $gw;
my $ip;
my $netmask;
my $mac;
for ($i; $i < $nic_nr; $i++) {
	$nic_name = "eth$i";
	if ( $old_nic_table{"$nic_name"}[0] eq "10000" && $flag eq 0 ) {
		$mac = $old_nic_table{"$nic_name"}[1];	
		#print "MAC: $mac";
		`echo -e "DEVICE=eth0\nHWADDR=$mac\nONBOOT=yes\nBOOTPROTO=none\nTYPE=Ethernet" > $new_ifcfg/ifcfg-eth0`;
		$flag ++;
	}
	if ($old_nic_table{"$nic_name"}[0] eq "10000" && $flag eq 1 ) {
		$mac = $old_nic_table{"$nic_name"}[1];	
		`echo -e "DEVICE=eth1\nHWADDR=$mac\nONBOOT=yes\nBOOTPROTO=none\nTYPE=Ethernet" > $new_ifcfg/ifcfg-eth1`;
		#print "MAC: $mac";
	}

#   How to diff the ip?
	if ($old_nic_table{"$nic_name"}[0] eq "1000" && $interflag eq 2) {
		$ip = $old_nic_table{"$nic_name"}[2];
		$netmask = $old_nic_table{"$nic_name"}[3];
		$gw = $old_nic_table{"$nic_name"}[4];
		$mac = $old_nic_table{"$nic_name"}[1];
		`echo -e "DEVICE=eth2\nHWADDR=$mac\nONBOOT=yes\nBOOTPROTO=none\nTYPE=Ethernet\nIPADDR=$ip\nNETMASK=$netmask\nGATEWAY=$gw" > $new_ifcfg/ifcfg-eth2`;
		$interflag ++;
	}

	if ($old_nic_table{"$nic_name"}[0] eq "1000" && $interflag eq 3) {
		$ip = $old_nic_table{"$nic_name"}[2];
		$netmask = $old_nic_table{"$nic_name"}[3];
		$gw = $old_nic_table{"$nic_name"}[4];
		$mac = $old_nic_table{"$nic_name"}[1];	
		`echo -e "DEVICE=eth3\nHWADDR=$mac\nONBOOT=yes\nBOOTPROTO=none\nTYPE=Ethernet\nIPADDR=$ip\nNETMASK=$netmask\nGATEWAY=$gw" > $new_ifcfg/ifcfg-eth3`;
	}
}

#goto END;
`cp -rf $new_ifcfg/ifcfg-eth* $ifcfg_conf`;

# Del the rule file
if (-e $nic_rules) {
	`rm -rf $nic_rules`;
}

# Redo 3times, Just for sure the modules will be loaded
$i = 3;
for ($i; $i > 0; $i --) {
	`rmmod igb`;
	sleep(3);
	`rmmod ixgbe`;
	sleep(3);
	`modprobe igb`;
	sleep(5);
	`modprobe ixgbe`;
	sleep(5);
	`ifdown eth0`;
	`ifdown eth1`;
	`ifdown eth2`;
	`ifdown eth3`;
	sleep(3);
	`ifup eth0`;
	`ifup eth1`;
	`ifup eth2`;
	`ifup eth3`;
	sleep(3);
}
`route add default gw $default_gw`;
print "modules reload over..\n";

## Check the nic shift
$nic_info = `ethtool eth0`;
if ($nic_info =~ /10000Mb/) {
	print "eth0 shift OK\n";
} else {
	print "eth0 shift failed\nGo to backup\n";
	`cp -rf $base/ifcfg_backup/ifcfg-eth* $ifcfg_conf`;
	goto RELOAD_FAILED;
}

$nic_info = `ethtool eth1`;
if ($nic_info =~ /10000Mb/) {
        print "eth1 shift OK\n";
} else {
        print "eth1 shift failed\nGo to backup\n";
	`cp -rf $base/ifcfg_backup/ifcfg-eth* $ifcfg_conf`;
	goto RELOAD_FAILED;
}

goto END;

## Job2: check the install_conf file
## NOT DONE HERE

# Begin to install
#`$base/lvs_install.sh`

RELOAD_FAILED:
if (-e $nic_rules) {
            `rm -rf $nic_rules`;
}

$i = 3;
for ($i; $i > 0; $i --) {
	`rmmod igb`;
	sleep(3);
	`rmmod ixgbe`;
	sleep(3);
	`modprobe igb`;
	sleep(5);
	`modprobe ixgbe`;
	sleep(5);
	`ifdown eth0`;
	`ifdown eth1`;
	`ifdown eth2`;
	`ifdown eth3`;
	sleep(3);
	`ifup eth0`;
	`ifup eth1`;
	`ifup eth2`;
	`ifup eth3`;
	sleep(3);
}
`route add default gw $default_gw`;
print "modules reload over..\n";

END:
	print "end...\n";

