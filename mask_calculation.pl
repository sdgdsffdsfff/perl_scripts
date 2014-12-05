#!/usr/bin/perl
use warnings;
use utf8;
use diagnostics;
use strict;
use 5.010;
############################################sub function define area#####################
sub calculation_of_mask{
	#define the parameters;
	my @ip_addr;
	my @network_address;
	my @broadcast_address;
	my @first_address;
	my @last_address;
	my @mask = qw{ 0 0 0 0 };
	my($ip_addr,$ip_mask) = @_;
	my $chushu = int($ip_mask/8);
	my $yushu = $ip_mask%8;
	my $summmary_of_last_mask=0;
	my $summmary_of_broadcast = 0;
	my $mask_length_surplus = (32 - $ip_mask -1)%8;
	
	###############################################
	if($ip_addr =~ /(?<ipa>[0-9]{1,3}).(?<ipb>[0-9]{1,3}).(?<ipc>[0-9]{1,3}).(?<ipd>[0-9]{1,3})/){
		($ip_addr[0],$ip_addr[1],$ip_addr[2],$ip_addr[3]) = ($+{ipa},$+{ipb},$+{ipc},$+{ipd});
	}
	if(!($ip_addr[0] > 0 and $ip_addr[0] <= 255 and $ip_addr[1] > 0 and $ip_addr[1] <= 255 and $ip_addr[2] >0 and $ip_addr[2] <= 255 and $ip_addr[3] >0 and $ip_addr[3] <= 255)){
		say "格式不正确，请输入正确的格式";
		return 0;
	}
	if($ip_mask <0 or $ip_mask > 32){
		say "格式不正确，请输入正确的格式";
		return 0;
	}
	##############transfer mask format into x.x.x.x
	foreach(0 .. $chushu-1){
		$mask[$_]=255;
	}
	for(my $i=7;$i>=8-$yushu;$i--){
		$summmary_of_last_mask += 2**$i;
	}
	$mask[$chushu]=$summmary_of_last_mask;

	###################calculation of  network address###############################
	foreach(0 .. 3){
		$network_address[$_] = $ip_addr[$_]&$mask[$_];
	}
	my $network_address = $network_address[0].".".$network_address[1].".".$network_address[2].".".$network_address[3];
	####################calculation of first address################################
	foreach(0 .. 2){
		$first_address[$_] = $network_address[$_];
	}
	$first_address[3] = $network_address[3] + 1;
	
	my $temp_first_address = $first_address[0].".".$first_address[1].".".$first_address[2].".".$first_address[3];
	
	####################calculation of broadcast address#################################
	for(my $i = $mask_length_surplus;$i >=0;$i--){
		$summmary_of_broadcast += (2**$i);
	}
	if($chushu == 0){
		@broadcast_address = ($network_address[0]+$summmary_of_broadcast,255,255,255)
	}elsif($chushu == 1){
		@broadcast_address = ($network_address[0],$network_address[1]+$summmary_of_broadcast,255,255)
	}elsif($chushu == 2){
		@broadcast_address = ($network_address[0],$network_address[1],$network_address[2]+$summmary_of_broadcast,255)
	}elsif($chushu == 3){
		@broadcast_address = ($network_address[0],$network_address[1],$network_address[2],$network_address[3]+$summmary_of_broadcast)
	}
	my $temp_broadcast_address= $broadcast_address[0].".".$broadcast_address[1].".".$broadcast_address[2].".".$broadcast_address[3];
	#######################calculation of last address###########################
	@last_address = ($broadcast_address[0],$broadcast_address[1],$broadcast_address[2],$broadcast_address[3]-1);
	my $temp_last_address = $last_address[0].".".$last_address[1].".".$last_address[2].".".$last_address[3];
	#######################print the result######################################
	say "Network address is  : $network_address";
	say "Broadcast address is: @broadcast_address";
	say "First address is    : $temp_first_address";
	say "Last address is     : $temp_last_address";
}

#########################################################################################
my $ip_address;
my $net_mask;
#my $ip = "10.128.56.5/21";
say "please input ip and mask,format:x.x.x.x/x";
my $ip = <STDIN>;


if($ip =~ /(?<ip>[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\/(?<mask>[0-9]{1,2}$)$/){
	 $ip_address = $+{ip};
	 $net_mask = $+{mask};
	 calculation_of_mask($ip_address,$net_mask);
}else{
	say "请输入正确的格式";
}






#say "please input ip/mask:(example:192.168.1.7/16)";
