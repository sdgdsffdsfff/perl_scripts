#!/usr/bin/perl
use warnings;
use utf8;
use diagnostics;
use strict;
use 5.010;
####################################################################################
#-----------------------------------------------------------------------------------
#
#-----------------------------------------------------------------------------------
sub merge_subnet{
	my %dict = @_;
	my @addr = keys %dict;
	my @mask = values %dict;
	my $minimal_mask=32;
	my @temp_mask;
	foreach(@mask){
		if($_ < $minimal_mask){
			$minimal_mask = $_;
		}
	}

	TOTAL:for(my $i = $minimal_mask; $i >= 1; $i--){
		my @result;
		my $chushu = int($i/8);  #3
		my $yushu = $i%8;        #0
		my $temp_mask_undef = 0;
		if($chushu == 0){
			if($yushu != 0){
			for(my $j = $yushu;$j >=1;$j--){
				$temp_mask_undef += (2**(8-$j));
			}
			}else{
				$temp_mask_undef = 0;
			}
			@temp_mask = ($temp_mask_undef,0,0,0);
		}
		elsif($chushu == 1){
			if($yushu != 0){
			for(my $j = $yushu;$j >=1;$j--){
				$temp_mask_undef += (2**(8-$j));
			}
			}else{
				$temp_mask_undef = 0;
			}
			@temp_mask = (255,$temp_mask_undef,0,0);
		}
		elsif($chushu == 2){
			if($yushu != 0){
			for(my $j = $yushu;$j >=1;$j--){
				$temp_mask_undef += (2**(8-$j));
			}
			}else{
				$temp_mask_undef = 0;
			}
			@temp_mask =(255,255,$temp_mask_undef,0)
		}
		elsif($chushu == 3){
			if($yushu != 0){
			for(my $j = $yushu;$j >=1;$j--){
				$temp_mask_undef += (2**(8-$j));
			}
			
			}else{
				$temp_mask_undef = 0;
			}
			@temp_mask =(255,255,255,$temp_mask_undef);

		}
		foreach(@addr){
			my @temp = split /\./,$_;
			my $net1 = $temp[0] & $temp_mask[0];
			my $net2 = $temp[1] & $temp_mask[1];
			my $net3 = $temp[2] & $temp_mask[2];
			my $net4 = $temp[3] & $temp_mask[3];
			my $network = join ".",$net1,$net2,$net3,$net4;
			push(@result,$network);
		}		
		my $compare = $result[0];
		SUB:foreach(@result){
			if($compare eq $_){
				next SUB;
				
			}else{
				next TOTAL;
			}
		}
		#say "finally result is $compare";
		return $compare;
		last;
	}
}
#------------------------------------------------------------------------------------
#BEGIN MAIN
#------------------------------------------------------------------------------------
my @infos = qw{
	192.168.1.1/26
	192.168.2.1/24
	192.168.3.1/27
	131.168.4.1/24
};

my %infos;
foreach(@infos){
	if($_ =~ /(?<ip>[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\/(?<mask>[0-9]{1,2}$)/){
		$infos{$+{ip}} = $+{mask};
	}else{
		say "format is wrong,please input right format~";
	}
}

my $result = merge_subnet(%infos);
if($result ne ""){
	say "last resulit iss $result";
	}else{
		say "there is no common subnet";
	}
