#!/usr/bin/perl

use strict;
use LWP;
use File::Basename;
use Config::Simple;
use Data::Dumper;
# curl ....
#
my $env_data = "/home/lvs/lvs_env.ini";
my $cmd = "curl -f -s -o $env_data http://218.30.117.221:80/lvs_env.ini";
my $ret = `$cmd`;
my %config;
Config::Simple->import_from($env_data, \%config) or die Config::Simple->error();


my $log_err     = "[ERROR]  ";
my $log_warning = "[WARNING]";
my $log_info    = "[INFO]   ";

my $lvs_env_check_version = $config{'GLOBAL.lvs_env_check_version'};
my $proc_ipv4 = $config{'GLOBAL.proc_ipv4'};
my $proc_ipvs = $config{'GLOBAL.proc_ipvs'};
my $alarm_path = $config{'GLOBAL.alarm_path'};
my $monitor_path = $config{'GLOBAL.monitor_path'};
my $kl_path = $config{'GLOBAL.kl_path'};
my $rc_local =  $config{'GLOBAL.rc_local'};
my $lvs_cron_file = $config{'GLOBAL.lvs_cron_file'};
my $logrotate= $config{'GLOBAL.logrotate'};
my $lvs_check_log = $config{'GLOBAL.lvs_check_log'};
my $firmware_kern_ver = $config{'GLOBAL.firmware_kern_ver'};		# firmware kernel version
my $l3_through = $config{'GLOBAL.l3_through'};		# l3 through, default 0
my $syn_proxy = $config{'GLOBAL.syn_proxy'};		# syn proxy switch, default 0
my $root_disk = $config{'GLOBAL.root_disk'};		# / partition require at least 10G
my $var_disk = $config{'GLOBAL.var_disk'};		# /var partition require at least 3G
my $mdm_req = $config{'GLOBAL.mdm_req'};		# memory require at least 10G 
my $wmnic_dri = $config{'GLOBAL.wmnic_dri'};	# 10 g nic driver
my $wmnic_dri_ver = $config{'GLOBAL.wmnic_dri_ver'};	# driver version
my $sys_ver = $config{'GLOBAL.sys_ver'};
my $modprobe_conf = $config{'GLOBAL.modprobe_conf'};

my $lvs_kern_ver = $config{'LVS.lvs_kern_ver'};	# lvs kernel version
my $nat_kern_ver = $config{'NAT.nat_kern_ver'};	# nat kernel version

my $host = `hostname`;
my $lvs_mode = "";		# lvs mode
my $failed = 0;

chomp $host;
chomp $lvs_mode;
chomp $l3_through;
chomp $syn_proxy;

chomp $mdm_req; 
chomp $wmnic_dri;
chomp $wmnic_dri_ver;


my %net_proc_table = (
	"/proc/sys/net/unix/max_dgram_qlen"	=>	$config{'GLOBAL_net_proc_table./proc/sys/net/unix/max_dgram_qlen'}, 
	"/proc/sys/net/ipv4/ip_forward"		=>	$config{'GLOBAL_net_proc_table./proc/sys/net/ipv4/ip_forward'},
	"/proc/sys/net/ipv4/ip_local_port_range"=>	$config{'GLOBAL_net_proc_table./proc/sys/net/ipv4/ip_local_port_range'},
);


my %global_proc_comm_table = (
	"/proc/sys/net/ipv4/vs/am_droprate"     =>	$config{'GLOBAL_proc_comm_table./proc/sys/net/ipv4/vs/am_droprate'},
	"/proc/sys/net/ipv4/vs/amemthresh"      =>	$config{'GLOBAL_proc_comm_table./proc/sys/net/ipv4/vs/amemthresh'},
	"/proc/sys/net/ipv4/vs/cache_bypass"    =>	$config{'GLOBAL_proc_comm_table./proc/sys/net/ipv4/vs/cache_bypass'},
	"/proc/sys/net/ipv4/vs/drop_entry"      =>	$config{'GLOBAL_proc_comm_table./proc/sys/net/ipv4/vs/drop_entry'},
	"/proc/sys/net/ipv4/vs/drop_packet"     =>	$config{'GLOBAL_proc_comm_table./proc/sys/net/ipv4/vs/drop_packet'},
	"/proc/sys/net/ipv4/vs/expire_nodest_conn"	=>	$config{'GLOBAL_proc_comm_table./proc/sys/net/ipv4/vs/expire_nodest_conn'},
	"/proc/sys/net/ipv4/vs/nat_icmp_send"   =>		$config{'GLOBAL_proc_comm_table./proc/sys/net/ipv4/vs/nat_icmp_send'},
	"/proc/sys/net/ipv4/vs/secure_tcp"      =>		$config{'GLOBAL_proc_comm_table./proc/sys/net/ipv4/vs/secure_tcp'},
	"/proc/sys/net/ipv4/vs/sync_threshold"  =>		$config{'GLOBAL_proc_comm_table./proc/sys/net/ipv4/vs/sync_threshold'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_close"	=>	$config{'GLOBAL_proc_comm_table./proc/sys/net/ipv4/vs/tcp_timeout_close'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_listen"	=>	$config{'GLOBAL_proc_comm_table./proc/sys/net/ipv4/vs/tcp_timeout_listen'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_none"	=>	$config{'GLOBAL_proc_comm_table./proc/sys/net/ipv4/vs/tcp_timeout_none'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_syn_recv" => $config{'GLOBAL_proc_comm_table./proc/sys/net/ipv4/vs/tcp_timeout_syn_recv'},
);

my %wzb_proc_comm_table = (
    "/proc/sys/net/ipv4/vs/ipbl_entry"              =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/ipbl_entry'},
    "/proc/sys/net/ipv4/vs/ip_route_opt_entry"      =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/ip_route_opt_entry'},
    "/proc/sys/net/ipv4/vs/ip_vs_icmp_opt"          =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/ip_vs_icmp_opt'},
    "/proc/sys/net/ipv4/vs/ip_vs_l3_backseq"        =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/ip_vs_l3_backseq'},
    "/proc/sys/net/ipv4/vs/ip_vs_L3_bport_max"      =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/ip_vs_L3_bport_max'},
    "/proc/sys/net/ipv4/vs/ip_vs_l3_conn_reuse"     =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/ip_vs_l3_conn_reuse'},
    "/proc/sys/net/ipv4/vs/ip_vs_l3_filter_timestamp"       =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/ip_vs_l3_filter_timestamp'},
    "/proc/sys/net/ipv4/vs/skb_buffer_cnt"                  =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/skb_buffer_cnt'},
    "/proc/sys/net/ipv4/vs/syn_proxy_ack_storm_threshold"   =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_ack_storm_threshold'},
    "/proc/sys/net/ipv4/vs/syn_proxy_auto"                  =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_auto'},
    "/proc/sys/net/ipv4/vs/syn_proxy_init_mss"      =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_init_mss'},
    "/proc/sys/net/ipv4/vs/syn_proxy_sack"          =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_sack'},
    "/proc/sys/net/ipv4/vs/syn_proxy_synack_ttl"    =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_synack_ttl'},
    "/proc/sys/net/ipv4/vs/syn_proxy_thresh"        =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_thresh'},
    "/proc/sys/net/ipv4/vs/syn_proxy_timestamp"     =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_timestamp'},
    "/proc/sys/net/ipv4/vs/syn_proxy_ttm_always_on_entry"   =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_ttm_always_on_entry'},
    "/proc/sys/net/ipv4/vs/syn_proxy_ttm_entry"     =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_ttm_entry'},
    "/proc/sys/net/ipv4/vs/syn_proxy_wait_data"     =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_wait_data'},
    "/proc/sys/net/ipv4/vs/syn_proxy_wscale"        =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_wscale'},
    "/proc/sys/net/ipv4/vs/tcp_conn_reuse_close"    =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/tcp_conn_reuse_close'},
    "/proc/sys/net/ipv4/vs/tcp_conn_reuse_close_wait"       =>      $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/tcp_conn_reuse_close_wait'},
    "/proc/sys/net/ipv4/vs/tcp_conn_reuse_fin_wait"         =>       $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/tcp_conn_reuse_fin_wait'},
    "/proc/sys/net/ipv4/vs/tcp_conn_reuse_last_ack"         =>       $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/tcp_conn_reuse_last_ack'},
    "/proc/sys/net/ipv4/vs/tcp_conn_reuse_time_wait"        =>       $config{'WZB_proc_comm_table./proc/sys/net/ipv4/vs/tcp_conn_reuse_time_wait'},
);


my %lvs_proc_comm_table = (
	"/proc/sys/net/ipv4/vs/ipbl_entry"		=>  	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/ipbl_entry'},
	"/proc/sys/net/ipv4/vs/ip_route_opt_entry"	=>  	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/ip_route_opt_entry'},
	"/proc/sys/net/ipv4/vs/ip_vs_icmp_opt"		=>	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/ip_vs_icmp_opt'},
	"/proc/sys/net/ipv4/vs/ip_vs_l3_backseq"        =>	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/ip_vs_l3_backseq'},
	"/proc/sys/net/ipv4/vs/ip_vs_L3_bport_max"	=>	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/ip_vs_L3_bport_max'},
	"/proc/sys/net/ipv4/vs/ip_vs_l3_conn_reuse"     =>	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/ip_vs_l3_conn_reuse'},
	"/proc/sys/net/ipv4/vs/ip_vs_l3_filter_timestamp"	=>	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/ip_vs_l3_filter_timestamp'},
	"/proc/sys/net/ipv4/vs/skb_buffer_cnt"			=>	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/skb_buffer_cnt'},
	"/proc/sys/net/ipv4/vs/syn_proxy_ack_storm_threshold"   =>  	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_ack_storm_threshold'},
	"/proc/sys/net/ipv4/vs/syn_proxy_auto"			=>	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_auto'},
	"/proc/sys/net/ipv4/vs/syn_proxy_init_mss"      =>  	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_init_mss'},
	"/proc/sys/net/ipv4/vs/syn_proxy_sack"		=>	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_sack'},
	"/proc/sys/net/ipv4/vs/syn_proxy_synack_ttl"    =>  	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_synack_ttl'},
	"/proc/sys/net/ipv4/vs/syn_proxy_thresh"        =>	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_thresh'},
	"/proc/sys/net/ipv4/vs/syn_proxy_timestamp"     =>	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_timestamp'},
	"/proc/sys/net/ipv4/vs/syn_proxy_ttm_always_on_entry"   =>  	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_ttm_always_on_entry'},
	"/proc/sys/net/ipv4/vs/syn_proxy_ttm_entry"     =>	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_ttm_entry'},
	"/proc/sys/net/ipv4/vs/syn_proxy_wait_data"     =>  	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_wait_data'},
	"/proc/sys/net/ipv4/vs/syn_proxy_wscale"        =>  	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/syn_proxy_wscale'},
	"/proc/sys/net/ipv4/vs/tcp_conn_reuse_close"    =>  	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/tcp_conn_reuse_close'},
	"/proc/sys/net/ipv4/vs/tcp_conn_reuse_close_wait"	=>   	$config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/tcp_conn_reuse_close_wait'},
	"/proc/sys/net/ipv4/vs/tcp_conn_reuse_fin_wait"		=>	 $config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/tcp_conn_reuse_fin_wait'},
	"/proc/sys/net/ipv4/vs/tcp_conn_reuse_last_ack"		=>	 $config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/tcp_conn_reuse_last_ack'},
	"/proc/sys/net/ipv4/vs/tcp_conn_reuse_time_wait"	=>	 $config{'LVS_proc_comm_table./proc/sys/net/ipv4/vs/tcp_conn_reuse_time_wait'},
);


my %lvs_nat_proc_table = (
	"/proc/sys/net/ipv4/vs/ip_vs_L3_bport_min"	=>	$config{'LVS_NAT_proc_table./proc/sys/net/ipv4/vs/ip_vs_L3_bport_min'},
	"/proc/sys/net/ipv4/vs/rs_route_cache_switch"   => 	 $config{'LVS_NAT_proc_table./proc/sys/net/ipv4/vs/rs_route_cache_switch'},
	"/proc/sys/net/ipv4/vs/syn_proxy_conn_reuse"    =>  	$config{'LVS_NAT_proc_table./proc/sys/net/ipv4/vs/syn_proxy_conn_reuse'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_close_wait"  =>	$config{'LVS_NAT_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_close_wait'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_established" =>	  $config{'LVS_NAT_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_established'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_fin_wait"    =>  	$config{'LVS_NAT_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_fin_wait'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_last_ack"    =>  	$config{'LVS_NAT_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_last_ack'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_synack"      =>  	$config{'LVS_NAT_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_synack'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_syn_sent"    =>  	$config{'LVS_NAT_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_syn_sent'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_time_wait"   =>  	$config{'LVS_NAT_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_time_wait'},
);

my %lvs_dr_proc_table = (
	"/proc/sys/net/ipv4/vs/syn_proxy_entry"		=>	$config{'LVS_DR_proc_table./proc/sys/net/ipv4/vs/syn_proxy_entry'},
	"/proc/sys/net/ipv4/vs/ip_vs_L3_bport_min"      =>	$config{'LVS_DR_proc_table./proc/sys/net/ipv4/vs/ip_vs_L3_bport_min'},
	"/proc/sys/net/ipv4/vs/syn_proxy_conn_reuse"    =>  	$config{'LVS_DR_proc_table./proc/sys/net/ipv4/vs/syn_proxy_conn_reuse'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_close_wait"  =>	$config{'LVS_DR_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_close_wait'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_established" =>	$config{'LVS_DR_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_established'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_fin_wait"    =>  	$config{'LVS_DR_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_fin_wait'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_last_ack"    =>  	$config{'LVS_DR_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_last_ack'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_synack"      =>  	$config{'LVS_DR_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_synack'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_syn_sent"    =>  	$config{'LVS_DR_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_syn_sent'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_time_wait"   =>  	$config{'LVS_DR_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_time_wait'},
);

my %lvs_cluster_proc_table = %lvs_nat_proc_table;

my %nat_proc_table = (
	"/proc/sys/net/ipv4/vs/big_nat_acl_level"	=>	$config{'NAT_proc_table./proc/sys/net/ipv4/vs/big_nat_acl_level'},
	"/proc/sys/net/ipv4/vs/big_nat_log_level"       =>  	$config{'NAT_proc_table./proc/sys/net/ipv4/vs/big_nat_log_level'},
	"/proc/sys/net/ipv4/vs/big_nat_policy_route_entry"	=>  $config{'NAT_proc_table./proc/sys/net/ipv4/vs/big_nat_policy_route_entry'},
	"/proc/sys/net/ipv4/vs/big_nat_port_range"      =>  	$config{'NAT_proc_table./proc/sys/net/ipv4/vs/big_nat_port_range'},
	"/proc/sys/net/ipv4/vs/big_nat_tc_entry"        =>	$config{'NAT_proc_table./proc/sys/net/ipv4/vs/big_nat_tc_entry'},
	"/proc/sys/net/ipv4/vs/big_nat_tcp_timestamp_disable"	=>  $config{'NAT_proc_table./proc/sys/net/ipv4/vs/big_nat_tcp_timestamp_disable'},
	"/proc/sys/net/ipv4/vs/icmp_timeout_bug"        =>	$config{'NAT_proc_table./proc/sys/net/ipv4/vs/icmp_timeout_bug'},
	"/proc/sys/net/ipv4/vs/icmp_timeout_normal"     =>  	$config{'NAT_proc_table./proc/sys/net/ipv4/vs/icmp_timeout_normal'},
	"/proc/sys/net/ipv4/vs/ip_route_opt_entry"      =>  	$config{'NAT_proc_table./proc/sys/net/ipv4/vs/ip_route_opt_entry'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_bug"			=>  $config{'NAT_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_bug'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_close_wait"  =>	$config{'NAT_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_close_wait'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_established" =>  	$config{'NAT_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_established'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_fin_wait"    =>  	$config{'NAT_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_fin_wait'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_last_ack"    =>  	$config{'NAT_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_last_ack'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_synack"      =>  	$config{'NAT_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_synack'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_syn_sent"    =>  	$config{'NAT_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_syn_sent'},
	"/proc/sys/net/ipv4/vs/tcp_timeout_time_wait"   =>  	$config{'NAT_proc_table./proc/sys/net/ipv4/vs/tcp_timeout_time_wait'},
	"/proc/sys/net/ipv4/vs/udp_timeout_bug"		=>  $config{'NAT_proc_table./proc/sys/net/ipv4/vs/udp_timeout_bug'},
	"/proc/sys/net/ipv4/vs/udp_timeout_normal"      =>  	$config{'NAT_proc_table./proc/sys/net/ipv4/vs/udp_timeout_normal'},
);

#my %lvs_nat_proc_table = (
#	"/proc/sys/net/ipv4/vs/syn_proxy_conn_reuse"	=>	"1",
#	"/proc/sys/net/ipv4/vs/syn_proxy_ttm_entry"		=>	"1",
#	"/proc/sys/net/ipv4/vs/tcp_timeout_synack"		=>	"2000",
#	"/proc/sys/net/ipv4/vs/tcp_timeout_syn_sent"	=>	"2000",
#	"/proc/sys/net/ipv4/vs/tcp_timeout_established"	=>	"180000",
#	"/proc/sys/net/ipv4/vs/tcp_timeout_time_wait"	=>	"30000",
#	"/proc/sys/net/ipv4/vs/tcp_timeout_fin_wait"	=>	"60000",
#	"/proc/sys/net/ipv4/vs/tcp_timeout_close_wait"	=>	"3000",
#	"/proc/sys/net/ipv4/vs/tcp_timeout_last_ack"	=>	"3000",
#	"/proc/sys/net/ipv4/vs/tcp_timeout_close"		=>	"10000",
#	"/proc/sys/net/ipv4/vs/ip_vs_L3_bport_min"		=>	"1130",
#	"/proc/sys/net/ipv4/vs/ip_vs_L3_bport_max"		=>	"65535",
#);

#my %lvs_dr_proc_table = (
#	"/proc/sys/net/ipv4/vs/syn_proxy_conn_reuse"	=>	"0",
#	"/proc/sys/net/ipv4/vs/syn_proxy_entry"			=>	"0",
#);

#my %nat_proc_tables = (
#);

my %lvs_md5_table = (
# lvs monitor md5 
	"/home/lvs/monitor/script/get_basic_stat.pl"	=>	$config{'GLOBAL_lvs_md5_table./home/lvs/monitor/script/get_basic_stat.pl'},
	"/home/lvs/monitor/script/get_ethtool.pl"	=>	$config{'GLOBAL_lvs_md5_table./home/lvs/monitor/script/get_ethtool.pl'},
	"/home/lvs/monitor/script/get_lvs_rate.pl"	=>	$config{'GLOBAL_lvs_md5_table./home/lvs/monitor/script/get_lvs_rate.pl'},
	"/home/lvs/monitor/script/get_lvs_stat.pl"	=>	$config{'GLOBAL_lvs_md5_table./home/lvs/monitor/script/get_lvs_stat.pl'},
	"/home/lvs/monitor/script/get_slabinfo.pl"	=>	$config{'GLOBAL_lvs_md5_table./home/lvs/monitor/script/get_slabinfo.pl'},

# alarm md5	
	"/home/lvs/alarm/dl_lvsm.pl"	=>	$config{'GLOBAL_lvs_md5_table./home/lvs/alarm/dl_lvsm.pl'},
	"/home/lvs/alarm/report.pl"	=>	$config{'GLOBAL_lvs_md5_table./home/lvs/alarm/report.pl'},
	"/home/lvs/alarm/run"		=>	$config{'GLOBAL_lvs_md5_table./home/lvs/alarm/run'},
	"/home/lvs/alarm/test.pl"	=>	$config{'GLOBAL_lvs_md5_table./home/lvs/alarm/test.pl'},
# nat md5	
	"/etc/syslog.conf"		=>	$config{'GLOBAL_lvs_md5_table./etc/syslog.conf'},
#	"/etc/logrotate.d/natlog"	=>	$config{'GLOBAL_lvs_md5_table./etc/logrotate.d/natlog'},

# logrotate md5
	"/etc/logrotate.d/lvs_rotate"	=>	$config{'GLOBAL_lvs_md5_table./etc/logrotate.d/lvs_rotate'},

# ulimit md5
	"/etc/security/limits.d/def.conf"   =>	$config{'GLOBAL_lvs_md5_table./etc/security/limits.d/def.conf'},

# cluster mode md5
	"/home/bvs-manager/bvs/common.pl"	=>	$config{'GLOBAL_lvs_md5_table./home/bvs-manager/bvs/common.pl'},
	"/home/bvs-manager/bvs/get_backend_ip"	=>	$config{'GLOBAL_lvs_md5_table./home/bvs-manager/bvs/get_backend_ip'},
	"/home/bvs-manager/bvs/get_vs_rs"	=>	$config{'GLOBAL_lvs_md5_table./home/bvs-manager/bvs/get_vs_rs'},
	"/home/bvs-manager/bvs/reload_keepalived"	=>	$config{'GLOBAL_lvs_md5_table./home/bvs-manager/bvs/reload_keepalived'},
	"/home/bvs-manager/bvs/show_vs"			=>	$config{'GLOBAL_lvs_md5_table./home/bvs-manager/bvs/show_vs'},
	"/home/bvs-manager/bvs/vip_adm"			=>	$config{'GLOBAL_lvs_md5_table./home/bvs-manager/bvs/vip_adm'},
);

my %nat_md5_table = (
# nat monitor md5 
	"/home/lvs/monitor/script/get_basic_stat.pl"	=>	$config{'NAT_md5_table./home/lvs/monitor/script/get_basic_stat.pl'},
	"/home/lvs/monitor/script/get_ethtool.pl"	=>	$config{'NAT_md5_table./home/lvs/monitor/script/get_ethtool.pl'},
	"/home/lvs/monitor/script/get_nat_stat.pl"	=>	$config{'NAT_md5_table./home/lvs/monitor/script/get_nat_stat.pl'},
	"/home/lvs/monitor/script/get_slabinfo.pl"	=>	$config{'NAT_md5_table./home/lvs/monitor/script/get_slabinfo.pl'},
);

my %lvs_dns_table = (
	"bjt"		=>	"220.181.127.173|220.181.127.240",
	"ccc"		=>	"123.125.74.57|123.125.74.58",
	"ccp"		=>	"58.68.225.101|115.182.38.173",
	"cct"		=>	"220.181.47.79|220.181.47.80",
	"dgt"		=>	"",
	"dxt"		=>	"115.182.38.173|115.182.38.240",
	"hyb"		=>	"220.181.156.252|220.181.156.247",
	"lft"		=>	"124.238.254.10|124.238.254.11",
	"njt"		=>	"202.102.97.225|202.102.97.226",
	"qht"		=>	"123.183.216.241|123.183.216.247",
	"shgt"		=>	"180.153.227.247|180.153.227.248",
	"sjc"		=>	"61.55.185.252|61.55.185.253",
	"vbe"		=>	"",
	"vcc"		=>	"",
	"vct"		=>	"",
	"vjc"		=>	"119.188.64.201|119.188.64.202",
	"vnet"		=>	"211.151.122.231|211.151.122.232",
	"xjt"		=>	"218.84.244.15|218.84.244.17",
	"zwt"		=>	"220.181.156.247|220.181.156.252",
	"zzbc"		=>	"182.118.20.199|182.118.20.200",
);

my @ganglia_tool = (
	"ganglia-gmond",
	"libconfuse",
	"libganglia",
);

my %lvs_tool_table = (
	"keepalived"	=>	$config{'GLOBAL_lvs_tool_table.keepalived'},
	"ipvsadm"	=>	$config{'GLOBAL_lvs_tool_table.ipvsadm'},
	"zebra"		=>	$config{'GLOBAL_lvs_tool_table.zebra'},
	"ospfd"		=>	$config{'GLOBAL_lvs_tool_table.ospfd'},
);

my %lvs_modules_table = (
	"ip_vs"		=>	$config{'LVS_modules_table.ip_vs'},
);

my %nat_modules_table = (
	"ip_vs"		=>	$config{'NAT_modules_table.ip_vs'},
);

my %nat_tool_table = (
	"keepalived"	=>	$config{'NAT_tool_table.keepalived'},
	"ipvsadm"		=>	$config{'NAT_tool_table.ipvsadm'},
);


my %process_table = (
	"keepalived"			=>	$config{'GLOBAL_process_table.keepalived'},
	"dl_lvsm.pl"			=>	$config{'GLOBAL_process_table.dl_lvsm.pl'},
	"supervise /home/lvs/alarm"	=>	$config{'GLOBAL_process_table.supervise /home/lvs/alarm'},
	"zebra"				=>	$config{'GLOBAL_process_table.zebra'},
	"ospfd"				=>	$config{'GLOBAL_process_table.ospfd'},
);


my @nat_crontab = (
#	"^\\*\\/1 \\* \\* \\* \\* root \\/home\\/lvs\\/monitor\\/control.py\$",
	"^0 0 \\* \\* \\* root sync && echo 2 > \\/proc\\/sys\\/vm\\/drop_caches\$",
#	"^\\*\\/1 \\* \\* \\* \\* root \\/home\\/lvs\\/lvs_status.pl",
);
my @lvs_crontab = (
#	"^\\*\\/1 \\* \\* \\* \\* root \\/home\\/lvs\\/monitor\\/control.py\$",
	"^0 0 \\* \\* \\* root sync && echo 2 > \\/proc\\/sys\\/vm\\/drop_caches\$",
	"^\\*\\/1 \\* \\* \\* \\* root \\/home\\/lvs\\/lvs_status.pl",
);

my @alarm_info = (
	"",
	"sys_lvs_alarm",
	"sys_lvs_alarm_emailonly"
);

my %alarm_service = (
	"1.1.1.1"   => \@alarm_info
);



sub write_log
{
# write lvs env check log
#	open(FILE, ">>$lvs_check_log") or die "Error: conld not read from $lvs_check_log, program halting.";
#	print FILE "[$host] $_[0]\n";
	my $tag = $_[0];
	my $msg = $_[1];
	print "[$host]$tag  $msg\n";
#	close(FILE);
}


sub doAlarm() {
    my $ua = LWP::UserAgent->new;
    my $hostname = `hostname`;
    $hostname =~ s/\.qihoo\.net$//g;
    chomp($hostname);
    my $title   = "[".$hostname."] ".$_[0];
    my $content = "[".$hostname."] ".$_[1];
    my $dosms = $_[2];
    my ($alarm_service) = $_[3];
    my $i = 0;
    my $vip = '1.1.1.1';
    my @info;

    if ($vip and @{$alarm_service->{$vip}}) {
	@info = @{$alarm_service->{$vip}};
	if ($info[0]) {
	    $title =~ s/$vip/$info[0]/g;
	    $content =~ s/$vip/$info[0]/g;
	}
    }

    my $baseurl = "http://alarms.ops.qihoo.net:8360/intfs/alarm_intf";
    if ($dosms == 1) {
	my @sms_list = split(/\|/, $info[1]); 
	if ($#sms_list >= 0) {    
	    for ($i = 0; $i <= $#sms_list; $i++) {
		my $url = $baseurl."?group_name=$sms_list[$i]&&subject=$title&content=$content";
		my $response = $ua->get($url);
	    }
	}
    } else {
	my @email_list = split(/\|/, $info[2]);
	if ($#email_list >= 0) { 
	    for ($i = 0; $i <= $#email_list; $i++) {
		my $url = $baseurl."?group_name=$email_list[$i]&&subject=$title&content=$content";
		my $response = $ua->get($url);
	    }
	}
    }
}

sub alarm_monitors($$)
{
    if(not defined($ARGV[0]) or $ARGV[0] eq "0") {
	return;	
    }
    my $date = `date +%c`;
    my $warn_msg = $_[0];
    my $rs_ip;
    my $vip;
	
    chomp($date);
    print "$date: $warn_msg\n";
    &doAlarm($warn_msg, $warn_msg, $_[1], \%alarm_service);
}
sub parse_diff_content(@)
{
    foreach my $data (@_){
	if($data=~/</){
	    my @vip= split / /,$data;
	    chomp $vip[1];
	    my $res = is_rs_down($vip[1]);
	    if ($res eq 0) {
		write_log($log_err, "the vip:$vip[1] in ipvsadm is additional");
	    }
	}
	if($data=~/>/){
	    my @vip= split / /,$data;
	    chomp $vip[1];
	    write_log($log_err, "the vip:$vip[1] is not in ipvsadm");
	}
    }
}

sub check_vip_list ()
{
    my $local_file_path='/etc/rc.local';
    my $ipvs_file_path='/home/vip_check/ipvs_data';
    my $rc_file_path='/home/vip_check/rc_data';
    my $lo_file_path='/home/vip_check/lo_data';

    my $ipvs_cmd="sudo ipvsadm -ln|grep TCP|awk '{split(\$2,ip,\":\");print ip[1]}'";
    my $local_cmd="cat $local_file_path | grep 'dev lo' | awk '{split(\$4,ip,\"/\");print ip[1]}'";
    my $ipaddr_cmd="ip addr list lo|grep 'scope global'|awk '{split(\$2,ip,\"/\") ; print ip[1]}'";

    my $res=`rm -rf /home/vip_check`;
    $res=`mkdir /home/vip_check`;
    open my $ipvs_fd,">$ipvs_file_path" or die ("Can\'t open ipvs_data ");
    open my $rc_fd,">$rc_file_path" or die ("Can\'t open ipvs_data ");
    open my $lo_fd,">$lo_file_path" or die ("Can\'t open ipvs_data ");

    my @ipvs_list_tmp=sort `$ipvs_cmd`;
    my @local_list=sort `$local_cmd`;
    my @ipaddr_list=sort `$ipaddr_cmd`;

    my %tmp;
    my @ipvs_list=grep { ++$tmp{ $_ } < 2; } @ipvs_list_tmp;

    print $ipvs_fd @ipvs_list;
    print $rc_fd @local_list;
    print $lo_fd @ipaddr_list;
#  write_log($log_info, "=======the vip difference between rc.local and ipvs==========");
    my @compare_res=`diff $ipvs_file_path $rc_file_path`;
    parse_diff_content(@compare_res);
#    write_log($log_info, "=======the vip difference between lo_dev and ipvs=========");
    @compare_res=`diff $ipvs_file_path $lo_file_path`;
    parse_diff_content(@compare_res);
}
sub check_mem()
{
#write_log("checking memory");
	$failed = 0;
	my $free = `free -g | grep Mem | awk -F " " '{print \$2}'`;
	chomp $free;
	if ($free < $mdm_req) {
		my $msg = "mem free < $mdm_req!";
#		write_log($log_warning, "$msg\n");
		alarm_monitors($msg, 1);
		write_log($log_warning, "memory free $free, require at least $mdm_req");
		($failed == 0) and $failed = 1;
	}
	if ($failed == 0) { 
#		write_log("checking memory success!\n");
	} else {
#		write_log("checking memory failed!\n");
	}   
}

sub check_disk()
{
###check_disk###
#	write_log("checking the disk");
	$failed = 0;
	my $root_size = `df -x tmpfs -P -l 2>/dev/null | grep -P "\/\$" | awk '{print \$2}'`;
	my $var_size = `df -x tmpfs -P -l 2>/dev/null | grep -P "\/var\$" | awk '{print \$2}'`;
	chomp $root_size;
	chomp $var_size;

	$root_size = int($root_size / 1024 / 1024);
	$var_size = int($var_size / 1024 / 1024);
	#write_log("Check the / partition: $root_size(G)");
	
	if (defined $root_size){
		if ($root_size <= $root_disk) { 
			my $msg = "sizeof /  < $root_size";
			alarm_monitors($msg, 1);
			write_log($log_warning, "the / partition is too small current size is $root_size G");

			($failed == 0) and $failed = 1;
		}   
	} else {
		write_log($log_err, "Error occurs when df!");
		write_log($log_err, "checking / disk failed!");
		my $msg = "df / failed!";
		alarm_monitors($msg, 1);
		($failed == 0) and $failed = 1;
	}

	#write_log("check /var partition: $var_size(G)");
	if (defined $var_size) {
		if ($var_size < $var_disk) {
			write_log($log_warning, "the /var partition is too small current size is $var_size G");
			my $msg = "sizeof /var < $var_size";
			alarm_monitors($msg, 1);
			($failed == 0) and $failed = 1;
		}   
	} else {
		write_log($log_err, "Error occurs when df!");
		write_log($log_err, "checking /var disk failed!");
		my $msg = "df /var failed!";
		alarm_monitors($msg, 1);
		($failed == 0) and $failed = 1;
	}
	if ($failed == 0 ) { 
#		write_log("check disk success!\n");
	} else {
#		write_log("check disk failed!\n");
	}
}

sub check_hw()
{
	
}

sub check_hostname()
{
	my $etc_hostname = `cat /etc/hosts | grep 127.0.0.1 | awk '{print \$2}' 2>/dev/null`;
	my $net_hostname = `cat /etc/sysconfig/network | grep HOSTNAME | awk -F "=" '{print \$2}' 2>/dev/null`;
	chomp $etc_hostname;
	chomp $net_hostname;
	if ( $host ne $etc_hostname or $host ne $net_hostname) {
		my $msg = "unmatch hostname in hosts and network!";
		alarm_monitors($msg, 1);
		write_log($log_err, "unmatch hostname in /etc/hosts or /etc/sysconfig/network with $host");
		($failed eq 0) and $failed = 1;
	}
}


sub check_system($)
{
#	write_log("checking system env");
	$failed = 0;
	my $kern_ver = @_[0];
	my $version = `uname -r`;
	chomp $kern_ver;
	chomp $version;
	if (0 and $kern_ver ne $version) {
		write_log($log_warning, "not the lastest kernel version: $version, expected $kern_ver");
		($failed == 0) and $failed = 1;
	}
	
	if ( (`echo "$version" | awk -F "-" '{print $1}' 2>/dev/null` eq $firmware_kern_ver) and \
		(! -e '/lib/firmware' or `ls -l /lib/firmware | wc -l | tr '\n' ' '` lt 2)) {
		write_log($log_err, "/lib/firmware not installed");
		my $msg = "firmeware not installed!";
		alarm_monitors($msg, 1);
		($failed == 0) and $failed = 1;
	}
	check_hostname();
	my $lvs_log = "/home/lvs/log/var_log";
	if (! -d $lvs_log) {
	    write_log($log_err, "$lvs_log not defined");
	    my $msg = "var_log not defined!";
	    alarm_monitors($msg, 1);
	    ($failed == 0) and $failed = 1;
	}
	
	my $res = `ls -al /var/ | grep "log -> $lvs_log"`;
	chomp $res;
	if ($res eq "") {
	    my $msg = "var/log no ln to var_log!";
	    alarm_monitors($msg, 1);
	    write_log($log_err, "soft link log -> $lvs_log not defined, please check.");
	    ($failed == 0) and $failed = 1;
	}

	if ($failed == 0) {
#		write_log("check system env success!\n")
	} else {
#		write_log("check system env failed!\n");
	}
}

# all RS is down : return 1
# Not ALL RS is down : return 0
sub is_rs_down($)
{
    my $ret = 1;
    my $line;
    my @tuple;
    my $vip = $_[0];
    my $ipvs_log = "/home/lvs/ipvs_log.log";
    `ipvsadm -ln > $ipvs_log`;
    open(FILE, "<$ipvs_log") or die "Error: conld not open file\n";
    while ($line = <FILE>) {
	chomp($line);
#	@tuple = split(/\s+/, $line);
	if ($line =~ /$vip:/) {
	    while ($line = <FILE>) {
	        chomp($line);
	        @tuple = split(/\s+/, $line);
	        if ($tuple[0] eq "TCP" || $tuple[0] eq "UDP" || $tuple[0] eq "ICMP") {
		   last;
		}
		if ($tuple[4] ne 0) {
		    $ret = 0;
		}
	    }
	}
    }
    close(FILE);
    return($ret);
}

sub cluster_vip_lo()
{
    my @vip_list = `ipvsadm  -ln | grep TCP | awk '{print \$2}' | awk -F ":" '{print \$1}'`;
    foreach my $vip (@vip_list) {
	chomp($vip);
	my $res = `grep "ip addr add $vip/32 dev lo" /etc/rc.local`;
	chomp($res);
	if ($res eq "") {
	    write_log($log_err, "vip $vip not defined in /etc/rc.local");
	    my $msg = "$vip not defined in rc.local!";
	    alarm_monitors($msg, 1);
	    ($failed == 0) and $failed = 1;
	}
	$res = `ip addr list lo | grep "inet $vip/32 scope global lo"`;
	chomp($res);
	if ($res eq "") {
	    my $ret = is_rs_down($vip);
	    if ($ret eq 0) {
		my $msg = "$vip not binded in lo!";
		alarm_monitors($msg, 1);
		write_log($log_err, "vip $vip not binded in lo");
		($failed == 0) and $failed = 1;
	    }
	}
    }
}

sub cluster_dns_route()
{
    my $idc = `hostname | awk -F "." '{print \$3}'`;
    chomp($idc);
    my @dns_list = split(/\|/, $lvs_dns_table{$idc});
    
    foreach my $dns (@dns_list) {
	chomp($dns);
	my $res = `grep $dns /etc/resolv.conf`;
	chomp($res);
	if ($res eq "") {
	    my $msg = "dns $dns not defined in resolv.conf";
	    alarm_monitors($msg, 1);
	    write_log("dns $dns not defined in /etc/resolv.conf");
	    ($failed == 0) and $failed = 1;
	}
	$res = `route -n | grep $dns`;
	chomp($res);
	if ($res eq "") {
	    my $msg = "dns $dns route to outside not defined!";
	    alarm_monitors($msg, 1);
	    write_log("dns $dns not defined in route table");
	    ($failed == 0) and $failed = 1;
	}
    }
}

sub ip_str2int($)
{
    my $ip = $_[0];
    chomp($ip);
#    print "ip_str2int: $ip\n";
    my @tmp = split(/\./, $ip);
    my $a = $tmp[0];
    my $b = $tmp[1];
    my $c = $tmp[2];
    my $d = $tmp[3];
    chomp($a);
    chomp($b);
    chomp($c);
    chomp($d);
#    print "2int a: $a\n";
#    print "2int b: $b\n";
#    print "2int c: $c\n";
#    print "2int d: $d\n";
    return ($a << 24) + ($b << 16) + ($c << 8) + $d;
}

sub check_ospfd_conf()
{
    my $ospfd_conf = "/usr/local/etc/ospfd.conf";
    
    if (! -f $ospfd_conf) {
	my $msg = "ospfd.conf uninstalled!";
	alarm_monitors($msg, 1);
	write_log($log_err, "opspfd not installed!");
	($failed == 0) and $failed = 1;
    } else {
	my $ospfd_hostname = `grep hostname $ospfd_conf | awk '{print \$2}'`;
	chomp($ospfd_hostname);
	if (0 and $ospfd_hostname ne $host) {
	    write_log($log_err, "hostname $ospfd_hostname defined in $ospfd_conf is wrong");
	    ($failed == 0) and $failed = 1;
	}

	my $router_id = `grep "ospf router-id" $ospfd_conf | awk '{print \$3}'`;
	my $router_id_int = ip_str2int($router_id);
	chomp($router_id);
	chomp($router_id_int);
	my $res = `ip addr list | grep "$router_id"`;
	chomp($res);
	if ($res eq "") {
	    my $msg = "router id $router_id not defined!";
	    alarm_monitors($msg, 1);
	    write_log($log_err, "router id $router_id not defined");
	    ($failed == 0) and $failed = 1;
	}

	my @ospfd_network = `grep network $ospfd_conf | awk '{print \$2}'`;
	my $flag = 0;
	my $ip = 0;
	my $mask = 0;
	foreach my $on (@ospfd_network) {
	    chomp($on);
	    my @tmp = split(/\//, $on);
	    $ip = ip_str2int(@tmp[0]);
	    $mask = @tmp[1];
	    chomp($ip);
	    chomp($mask);
            my $a = $router_id_int >> (32 - $mask);
	    my $b = $ip >> (32 - $mask);
	    if (($router_id_int >> (32 - $mask)) eq ($ip >> (32 - $mask))) {
		$flag = 1;
		last;
	    } 
	}
	if ($flag == 0) {
	    my $base_name = `basename $ospfd_conf`;
	    chomp $base_name;
	    my $msg = "$router_id not defined in $base_name";
	    alarm_monitors($msg, 1);
	    write_log($log_err, "$router_id not in $ospfd_conf");
	    ($failed == 0) and $failed = 1;
	}

	my @vip_list = `ipvsadm -ln | grep TCP | awk '{print \$2}' | awk -F ":" '{print \$1}'`;
	foreach my $vip (@vip_list) {
	    chomp($vip);
	    $flag = 0;
	    foreach my $on (@ospfd_network) {
		chomp($on);
		my @tmp = split(/\//, $on);
		$ip = ip_str2int(@tmp[0]);
		$mask = @tmp[1];
		chomp($ip);
		chomp($mask);
	    	my $a = ip_str2int($vip) >> (32 - $mask);
		my $b = $ip >> (32 - $mask);
		if ($a eq $b) {
		    $flag = 1;
		    last;
		}
	    }
	    if ($flag eq 0) {
		my $base_name = `basename $ospfd_conf`;
		chomp $base_name;
		my $msg = "$vip not defined in $base_name";
		alarm_monitors($msg, 1);
		write_log($log_err, "$vip not in $ospfd_conf");
		($failed == 0) and $failed = 1;
	    }
	}
    }
}

sub check_zebra_conf()
{
    my $zebra_conf = "/usr/local/etc/zebra.conf";
    if (! -f $zebra_conf) {
	my $msg = "zebra.conf uninstalled!";
	alarm_monitors($msg, 1);
	write_log($log_err, "zebra not installed");
	($failed == 0) and $failed = 1;
    } else {
	my $zebra_hostname = `grep hostname $zebra_conf | awk '{print \$2}'`;
	chomp($zebra_hostname);
	if (0 and $zebra_hostname ne $host) {
	    write_log($log_err, "hostname $zebra_hostname defined in $zebra_conf is wrong");
	    ($failed == 0) and $failed = 1;
	}
    }
}

sub check_cluster_system($)
{
#    write_log("checking cluster system");
    my $faile = 0;
    check_system($_[0]);
    check_ospfd_conf();
    check_zebra_conf();
    cluster_vip_lo();
    #cluster_dns_route();

    if ($failed ==0) {
#	write_log("check cluster system success!\n");
    } else {
#	write_log("check system env failed!\n");
    }
}

sub check_nic()
{
#	write_log("checking nic config:");
	$failed = 0;

	my @nic_list = `ls /proc/sys/net/ipv4/conf/ 2</dev/null`;
	foreach my $nic (@nic_list) {
		chomp $nic;
		my $rpf = `cat /proc/sys/net/ipv4/conf/$nic/rp_filter 2</dev/null`;
		my $arpi = `cat /proc/sys/net/ipv4/conf/$nic/arp_ignore 2</dev/null`;
		my $arpa = `cat /proc/sys/net/ipv4/conf/$nic/arp_announce 2</dev/null`;
		chomp $rpf;
		chomp $arpi;
		chomp $arpa;
		if ($rpf != 0) {
			write_log($log_err, "unexpected /proc/sys/net/ipv4/conf/$nic/rp_filter = $rpf, expected 0");
			($failed == 0) and $failed = 1;
		}
		if ($arpi ne 1) {
			write_log($log_err, "unexpected /proc/sys/net/ipv4/conf/$nic/arp_ignore = $arpi, expected 1");
			($failed == 0) and $failed = 1;
		}
		if ($arpa ne 2) {
			write_log($log_err, "unexpected /proc/sys/net/ipv4/conf/$nic/arp_announce = $arpa, expected 2");
			($failed == 0) and $failed = 1;
		}
	}
	
	my @nic_list =`ip addr | grep "^[0-9]*:" | awk -F ": " '{print \$2}' | sed 's/@.*//g' 2</dev/null`;
	my @nic_offload;
	if ($sys_ver =~ /5\.4/) {
		@nic_offload = (
			"tcp segmentation offload",
			"generic segmentation offload",
			"generic-receive-offload",
		) 
	} elsif ($sys_ver =~ /6\.2/) {
		@nic_offload = (
			"tcp-segmentation-offload",
			"generic-segmentation-offload",
			"generic-receive-offload",
		)   
	}

	foreach my $nic (@nic_list) {
		chomp $nic;
		last if ( $nic =~ /^sit/);
		if ($nic ne "lo") {
			#my $driver = `ethtool -i $nic 2>&1 | grep "driver" | awk -F ": " '{print \$2}'`;
			#my $dri_ver = `ethtool -i $nic 2>&1 | grep "version" | awk -F ": " '{print \$2}'`;
			my @driver = split(/: /, `ethtool -i $nic 2>&1 | grep "^driver" 2>/dev/null`);
			my @dri_ver = split(/: /, `ethtool -i $nic 2>&1 | grep "^version" 2>/dev/null`);
			chomp @driver[1];
			chomp @dri_ver[1];
			if (@driver[1] =~ /^$wmnic_dri$/) {
				if (@dri_ver[1] ne "$wmnic_dri_ver") {
					write_log($log_warning, "old ixgbe driver version: @dri_ver[1]");
					($failed == 0) and $failed = 1;
				}
			}
		}
		foreach my $value (@nic_offload) {
			my @status = split(/: /, `ethtool -k $nic 2>&1 | grep "^$value" 2</dev/null`);
			chomp $status[1];
			if ($status[1] ne "off") {
				write_log($log_err, "offload feature $value in $nic: $status[1], please check");
				my $msg = "$value in $nic: $status[1]!";
				alarm_monitors($msg, 1);
				($failed == 0) and $failed = 1;
			}
		}
	}
	if ($failed == 0) {
#		write_log("check nic config success!\n");
	} else {
#		write_log("check nic config failed!\n");
	}
}

sub check_net()
{
#	write_log("checking net config");
	$failed = 0;
	
	foreach my $para (keys %net_proc_table) {
		last if (! -e $para);
		my $value = `cat $para 2>/dev/null`;
		chomp $value;
		if ($value != $net_proc_table{$para}) {
			write_log($log_err, "unexpected $para = $value, expected $net_proc_table{$para}");
			($failed == 0) and $failed = 1;
		}
	}
	my @ipt = split(/ /, `/etc/init.d/iptables status 2>/dev/null`);
	chomp @ipt[2];
	if (@ipt[2] !=~ "stopped") {
		write_log($log_err, "iptables is running");
		my $msg = "iptables is running!";
		alarm_monitors($msg, 1);
		($failed == 0) and $failed = 1;
	}
	my @ip6t = split(/ /, `/etc/init.d/ip6tables status 2>/dev/null`);
	chomp @ip6t[2];
	if (@ip6t[2] !=~ "stopped") {
		write_log($log_err, "ip6tables is running");
		my $msg = "ip6tables is runing!";
		alarm_monitors($msg, 1);
		($failed == 0) and $failed = 1;
	}
	my @irq = split(/ /, `/etc/init.d/irqbalance status 2>/dev/null`);
	chomp @irq[2];
	if (@irq[2] !=~ "stopped") {
		write_log($log_err, "irqbalance is running");
		my $msg = "irqbalance is running!";
		alarm_monitors($msg, 1);
		($failed == 0) and $failed = 1;
	}
	if ($lvs_mode =~ /^lvs_cluster$|^LVS_CLUSTER$/) {
		my $default_route = `route -n | grep "^0.0.0.0" | awk '{print \$2}'`;
		my $ospfd_route = `cat /etc/sysconfig/network-scripts/ifcfg-eth0 | grep "^GATEWAY" | awk -F '=' '{print \$2}'`;
		chomp $default_route;
		chomp $ospfd_route;
		if ($default_route ne $ospfd_route) {
			write_log($log_err, "default route $default_route not match with ospfd route $ospfd_route");
			my $msg = "default route $default_route not match with ospfd route $ospfd_route!";
			alarm_monitors($msg, 1);
			($failed == 0) and $failed = 1;
		}
	}
	if ($failed == 0) {
#		write_log("checking net config success!\n");
	} else {
#		write_log("checking net config failed!\n");
	}
}

sub check_nat_conf_file()
{
#	write_log("checking nat config file");
	$failed = 0;
	my $res = `cat /etc/rc.local | grep "^/etc/rc.d/lvs_rc.local" 2>/dev/null`;
	if ($res eq "") {
		my $msg = "lvs_rc.local not defined in rc.local!";
		alarm_monitors($msg, 1);
		write_log($log_err, "lvs_rc.local not define in /etc/rc.local");
		($failed == 0) and $failed = 1;
	}
	$res = `cat /etc/sysctl.conf | grep "net\.ipv4\.conf\.default\.rp_filter" 2>/dev/null`;
	if ($res ne "") {
		my @value = split(/=/, $res);
		chomp @value[1];
		@value[1] =~ s/\s+//g;
		if (@value[1] ne 0) {
			write_log($log_err, "unexecped net.ipv4.conf.default.rp_filter = @value[1] in /etc/sysctl.conf, expeced 0");
			($failed == 0) and $failed = 1;
		}
	}
	if ($failed == 0) {
#		write_log("check nat config file success!\n");
	} else {
#		write_log("check nat config file failed!\n");
	}
}

sub check_lvs_dr_conf_file()
{
#	write_log("check lvs dr config file");
	my $faild = 0;
	check_nat_conf_file();
	if ($failed == 0) {
#		write_log("check lvs dr config file success!\n");
	} else {
#		write_log("check lvs dr config file failed!\n");
	}
}

sub check_lvs_nat_conf_file()
{
#	write_log("checking lvs nat config file");
	my $failed = 0;
	my $res = `cat /etc/rc.local | grep "^/etc/rc.d/lvs_rc.local" 2>/dev/null`;

	if ($res eq "") {
		my $msg = "lvs_rc.local not defined in rc.lcoal!";
		alarm_monitors($msg, 1);
		write_log($log_err, "lvs_rc.local not define in /etc/rc.local");
		($failed == 0) and $failed = 1;
	}
	$res = `cat $modprobe_conf | grep "options ip_vs ip_vs_L3_through" 2>/dev/null`;
	if (defined $res) {
		my @value = split(/=/, $res);
		chomp @value[1];
		if (@value[1] != $l3_through) {
			my $msg = "L3_through undefined in modprobe.conf!";
			alarm_monitors($msg, 1);
			write_log($log_err, "unexpected L3_through in $modprobe_conf");
			($failed eq 0) and $failed = 1;
		}
	}


        $res = `cat /etc/sysctl.conf | grep "net\.ipv4\.conf\.default\.rp_filter" | wc -l 2>/dev/null`;
        if ($res == 1) {
	    $res = `cat /etc/sysctl.conf | grep "net\.ipv4\.conf\.default\.rp_filter" 2>/dev/null`;
	    if ($res ne "") {
		my @value = split(/=/, $res);
		chomp @value[1];
		@value[1] =~ s/\s+//g;
		if (@value[1] ne 0) {
		    write_log($log_err, "unexecped net.ipv4.conf.default.rp_filter =  @value[1] in /etc/sysctl.conf, expeced 0");
		    ($failed == 0) and $failed = 1;
		}
	   }
        } else {
	    my @res_tab;
            @res_tab = `cat /etc/sysctl.conf | grep "net\.ipv4\.conf\.default\.rp_filter" 2>/dev/null`;
            foreach $res (@res_tab) {
		if ($res ne "") {
		    my @value = split(/=/, $res);
		    chomp @value[1];
		    @value[1] =~ s/\s+//g;
		    if (@value[1] ne 0) {
			write_log($log_err, "unexecped net.ipv4.conf.default.rp_filter =  @value[1] in /etc/sysctl.conf, expeced 0");
			($failed == 0) and $failed = 1;
		    }
		}
	    }
        }		    
	if($failed == 0) {
#		write_log("check lvs nat config file success\n");
	} else {
#		write_log("check lvs nat config file failed!\n");
	}
}

sub check_lvs_cluster_conf_file()
{
	check_lvs_nat_conf_file();
}


sub check_global_comm_proc()
{
	foreach my $para (keys %global_proc_comm_table) {
		last if (! -e $para);
		my $value = `cat $para 2>/dev/null`;
		chomp $value;
		#write_log("debug: $para = $value");
		if($value ne $global_proc_comm_table{$para}) {
			write_log($log_err, "unexpected $para = $value, expected $global_proc_comm_table{$para}");
			($failed == 0) and $failed = 1;
		}
	}
}

sub check_lvs_comm_proc()
{
	foreach my $para (keys %lvs_proc_comm_table) {
		last if (! -e $para);
		my $value = `cat $para 2>/dev/null`;
		chomp $value;
		#write_log("debug: $para = $value");
		if($value ne $lvs_proc_comm_table{$para}) {
		    my $host = `hostname`;
		    if ($host =~ /wzb/ && $value eq $wzb_proc_comm_table{$para}) {
			next;
		    }
		    write_log($log_err, "unexpected $para = $value, expected $lvs_proc_comm_table{$para}");
		    ($failed == 0) and $failed = 1;
		}
	}
}

sub check_lvs_nat_proc()
{
	check_global_comm_proc();
	check_lvs_comm_proc();
	foreach my $para (keys %lvs_nat_proc_table) {
		last if (! -e $para);
		my $value = `cat $para 2>/dev/null`;
		chomp $value;
		#write_log("debug: $para = $value");
		if ($value ne $lvs_nat_proc_table{$para}) {
			write_log($log_err, "unexpected $para = $value, expected $lvs_nat_proc_table{$para}");
			($failed == 0) and $failed = 1;
		}
	}
	#return if (! -e $para);
	my $syn_proxy_entry = `cat /proc/sys/net/ipv4/vs/syn_proxy_entry 2>/dev/null`;
	chomp $syn_proxy_entry;
	if ($syn_proxy != $syn_proxy_entry) {
		write_log($log_err, "unexpected /proc/sys/net/ipv4/vs/syn_proxy_entry = $syn_proxy_entry, expect $syn_proxy");
		($failed == 0) and $failed = 1;
	}
}

sub check_lvs_dr_proc()
{
	check_global_comm_proc();
	check_lvs_comm_proc();
	foreach my $para (keys %lvs_dr_proc_table) {
		last if (! -e $para);
		my $value = `cat $para 2>/dev/null`;
		chomp $value;
		#write_log("debug: $para = $value");
		if ($value ne $lvs_dr_proc_table{$para}) {
			write_log($log_err, "unexpected $para = $value, expected $lvs_dr_proc_table{$para}");
			($failed == 0) and $failed = 1;
		}
	}
}

sub check_nat_proc()
{
	foreach my $para (keys %nat_proc_table) {
		last if (! -e $para);
		my $value = `cat $para 2>/dev/null`;
		chomp $value;
		#write_log("debug: $para = $value");
		if ($value ne $nat_proc_table{$para}) {
			write_log($log_err, "unexpected $para = $value, expected $nat_proc_table{$para}");
			($failed == 0) and $failed = 1;
		}
	}
}

sub check_cluster_proc()
{
	check_global_comm_proc();
	check_lvs_comm_proc();
	foreach my $para (keys %lvs_cluster_proc_table) {
		last if (! -e $para);
		my $value = `cat $para 2>/dev/null`;
		chomp $value;
		#write_log("debug: $para = $value");
		if ($value ne $lvs_cluster_proc_table{$para}) {
			write_log($log_err, "unexpected $para = $value, expect $lvs_cluster_proc_table{$para}");
			($failed == 0) and $failed = 1;
		}
	}
}

sub get_authority($)
{
    my $mode = (stat($_[0]))[2];
#    printf "%04o\n", ($mode & 007777);
    return ($mode & 007777);
}

sub ergodic_dir($)
{
    my $para = @_[0];
    chomp($para);
    my $auth = get_authority($para);
    chomp($auth);
    if ($auth ne 00777) {
	write_log($log_err, "unexpected file $para authority, please check.");
	($failed == 0) and $failed = 1;
    }  
    if (-d $para) {
	opendir(fd, $para) || die "cannot open $para':$!";
	my @files = readdir fd;
	for (my $index = 0; $index < @files; $index++){ 
		if ($files[$index] eq '.' or $files[$index] eq "..") {
			next;
		}
		chomp($files[$index]);
		my $file_path="$para"."/"."$files[$index]";
		ergodic_dir($file_path);
	}
    }
}


## Do not check keepalived any more
sub check_keepalived()
{
#    write_log("check keepalived");
    $failed = 0;

#    if (! -d $kl_path) {
#	write_log("keepalived not installed, please check\n");
#	($failed == 0) and $failed = 1;
#    } else {
#    	ergodic_dir($kl_path);
#    }
    
    my $info = `ls -al /proc/\$(ps axf | grep keepalived | grep -v grep | head -n 1 | awk '{print \$1}') | grep keepalived | awk '{print \$9, \$10, \$11, \$12}'`;
    chomp $info;
    $info =~ s/\s+$//;
    if ($info !~ /exe\s+->\s+\/sbin\/keepalived$/) {
	    write_log($log_err, "keepalived is removed: $info!");
	    ($failed == 0) and $failed = 1;
    }

    if ($failed == 0) {
#	write_log("check keepalived success!\n");
    } else {
#	write_log("check keepalived failed!\n");
    }
}

sub check_lvs_nat()
{
#	write_log("checking lvs nat config");
	$failed = 0;
	check_lvs_nat_proc();
	if ($failed == 0) { 
#		write_log("check lvs nat config success!\n");
	} else {	
#		write_log("check lvs nat config failed!\n");
	}
}

sub check_lvs_dr()
{
#	write_log("checking lvs dr config");
	$failed = 0;
	check_lvs_dr_proc();
	if ($failed == 0) { 
#		write_log("check lvs dr config success!\n");
	} else {	
#		write_log("check lvs dr config failed!\n");
	}
}

sub check_nat()
{
#	write_log("checking nat config");
	$failed = 0;
	check_nat_proc();
	if ($failed == 0) { 
#		write_log("check nat config success!\n");
	} else {
#		write_log("check nat config failed!\n");
	}
}

sub check_lvs_cluster()
{
#	write_log("checking lvs cluster config");
	$failed = 0;
	check_cluster_proc();
	if ($failed == 0) {
#		write_log("check lvs cluster config success!\n");
	} else {
#		write_log("check lvs cluster config falied!\n");
	}
}

sub check_alarm_conf()
{
	
	my $alarm_conf = $alarm_path."/conf";
	open CONF_FILE, "<$alarm_conf" or die("Could not open configure file!\n");
	my $sms_group_flag = 0;
	my $email_group_flag = 0;
	my $module_flag = 0;

	while (<CONF_FILE>) {
		if (/time\s*\{/../\}/) {
			if ($_ =~ /^\s*interval_time\s*\=\s*([0-9\.]+)\s*;/) {
				if ($1 != 3) {
					write_log($log_err, "unexpected value in $alarm_conf interval_time!");
					($failed == 0) and $failed = 1;
				}
			}elsif ($_ =~ /^\s*retry_number\s*\=\s*([0-9\.]+)\s*;/) {
				if ($1 != 3) {
					write_log($log_err, "unexpected value in $alarm_conf retry_number!");
					($failed == 0) and $failed = 1;
				}
			}
		} elsif (/processes\s*\{/../\}/) {
			if ($_ =~ /^\s*keepalived\s*\=\s*([0-9\.]+)\s*;/) {
				if ($1 != 3) {
					write_log($log_err, "unexpected value in $alarm_conf keepalived");
					($failed == 0) and $failed = 1;
				}
			}
		} elsif (/threshold\s*\{/../\}/) {
			if ($_ =~ /^\s*cpu_soft\s*\=\s*([0-9\.]+)\s*;/) {
				if ($1 != 0.9) {
					write_log($log_err, "unexpected value in $alarm_conf cpu_soft");
					($failed == 0) and $failed = 1;
				}
			} elsif ($_ =~ /^\s*memory_used\s*\=\s*([0-9\.]+)\s*;/) {
				if ($1 != 0.9) {
					write_log($log_err, "unexpected value in $alarm_conf memory_used");
					($failed == 0) and $failed = 1;
				}
			} elsif ($_ =~ /^\s*disk_used_rate\s*\=\s*([0-9\.]+)\s*;/) {
				if ($1 != 0.9) {
					write_log($log_err, "unexpected value in $alarm_conf disk_used_rate");
					($failed == 0) and $failed = 1;
				}
			}
		} elsif (/healthcheck\s*\{/../\}/) {
			if ($_ =~ /^\s*nohealthcheck_times\s*\=\s*([0-9\.]+)\s*;/) {
				if ($1 != 7) {
					write_log($log_err, "unexpected value in $alarm_conf nohealthcheck_times");
					($failed == 0) and $failed = 1;
				}
			}
		} elsif (/sms_group\s*\{/../\}/) {
			if ($_ =~ /^\s*sys_lvs_alarm\s*;/) {
				$sms_group_flag = 1;
			#	write_log($log_err, "sys_lvs_alarm defined in $alarm_conf sms_group");
			}
		} elsif (/email_group\s*\{/../\}/) {
			if ($_ =~ /^\s*sys_lvs_alarm_emailonly\s*;/) {
				$email_group_flag = 1;
			#	write_log($log_err, "sys_lvs_alarm_emailonly defined in $alarm_conf email_group");
			}
		} elsif (/modules\s*\{/../\}/) {
			if ($_ =~ /^\s*lvs_modules\s*=\s*ip_vs/) {
				$module_flag = 1;
			#	write_log($log_err, "lvs_modules depend defined in $alarm_conf");
			}
		}
	}
	if ($sms_group_flag == 0) {
		write_log($log_err, "sys_lvs_alarm not defined in $alarm_conf sms_group");
		($failed ==0 ) and $failed = 1;
	}
	if ($email_group_flag == 0) {
		write_log($log_err, "sys_lvs_alarm_emailonly not defined in $alarm_conf email_group");
		($failed ==0 ) and $failed = 1;
	}
	if ($module_flag == 0) {
		write_log($log_err, "lvs_modules not defined in $alarm_conf");
		($failed ==0 ) and $failed = 1;
	}
	close CONF_FILE;
}

sub check_alarm()
{
#	write_log("checking alarm config");
	$failed = 0;

	my @file_list = (
		"/home/lvs/alarm/dl_lvsm.pl",
		"/home/lvs/alarm/report.pl",
		"/home/lvs/alarm/test.pl",
	);
	foreach my $file (@file_list){	
		#my $md5 = get_md5($file);
		my $md5 = `md5sum $file | awk '{print \$1}' 2>/dev/null`;
		chomp $md5;
		if ($md5 ne $lvs_md5_table{$file}) {
			write_log($log_err, "md5 error for $file");
			my $file_name = `basename $file`;
			chomp $file_name;
			my $msg = "$file_name md5 err!";
			alarm_monitors($msg, 1);
			($failed == 0) and $failed = 1;
		}
	}
	check_alarm_conf();
	if ($failed == 0) {  
#		write_log("checking alarm config success!\n");
	} else {	
#		write_log("checking alarm config failed!\n");
	}	
}

sub check_nat_monitor()
{
#	write_log("checking nat monitor");
	$failed = 0;
	my @file_list = (
		'/home/lvs/monitor/script/get_basic_stat.pl',
		'/home/lvs/monitor/script/get_ethtool.pl',
		'/home/lvs/monitor/script/get_nat_stat.pl',
		'/home/lvs/monitor/script/get_slabinfo.pl',
	);
	foreach my $file (@file_list){	
		#my $md5 = get_md5($file);
		my $md5 = `md5sum $file | awk '{print \$1}' 2>/dev/null`;
		chomp $md5;

		if ($md5 ne $nat_md5_table{$file}) {
			my $base_name = `basename $file`;
			chomp $base_name;
			my $msg = "$base_name md5 err!";
			alarm_monitors($msg, 1);
			write_log($log_err, "md5 error for $file");
			($failed == 0) and $failed = 1;
		}
	}
	if ($failed == 0) { 
#		write_log("checing nat monitor success!\n");
	} else {	
#		write_log("checing nat monitor failed!\n");
	}
}

sub check_monitor()
{
#	write_log("checking monitor");
	$failed = 0;
	my @file_list = (
		'/home/lvs/monitor/script/get_basic_stat.pl',
		'/home/lvs/monitor/script/get_ethtool.pl',
		'/home/lvs/monitor/script/get_lvs_rate.pl',
		'/home/lvs/monitor/script/get_lvs_stat.pl',
		'/home/lvs/monitor/script/get_slabinfo.pl',
	);
	foreach my $file (@file_list){	
		my $md5 = `md5sum $file | awk '{print \$1}' 2>/dev/null`;
		chomp $md5;
		if ($md5 ne $lvs_md5_table{$file}) {
			my $base_name = `basename $file`;
			chomp $base_name;
			my $msg = "$base_name md5 err!";
			alarm_monitors($msg, 1);
			write_log($log_err, "md5 error for $file");
			($failed == 0) and $failed = 1;
		}
	}
	if ($failed == 0) { 
#		write_log("check monitor success!\n");
	} else {
#		write_log("check monitor failed!\n");
	}
}

sub check_crontab($)
{ 
#	write_log("checking crontab");
	
	$failed = 0;
	my $mode = $_[0];
	if ($mode =~ /^nat$|^NAT$/) {
	    foreach my $crond (@nat_crontab){
		    my $res = `cat $lvs_cron_file | grep "$crond" 2>/dev/null`;
		    if ($? ne 0) {
			    my $base_name = `basename $lvs_cron_file`;
			    chomp $base_name;
			    my $msg = "incomplete content in $base_name";
			    alarm_monitors($msg, 1);
			    write_log($log_err, "$crond undefined in $lvs_cron_file");
			    ($failed == 0) and $failed = 1;
		    }
	    }
	
	} else {
#	    my @contab = @_[0];
	    foreach my $crond (@lvs_crontab){
		    my $res = `cat $lvs_cron_file | grep "$crond" 2>/dev/null`;
		    if ($? ne 0) {
			    my $base_name = `basename $lvs_cron_file`;
			    chomp $base_name;
			    my $msg = "incomplete content in $base_name";
			    alarm_monitors($msg, 1);
			    write_log($log_err, "$crond undefined in $lvs_cron_file");
			    ($failed == 0) and $failed = 1;
		    }
	    }
	}
	if ($failed == 0) { 
#		write_log("check crontab success!\n");
	} else {
#		write_log("check crontab failed!\n");
	}
}

sub check_ganglia()
{
#	foreach my $tool (@ganglia_tools){
#		my $res = `rpm -qa | grep "$tool" 2>/dev/null`;
#		chomp $res;
##		if (not defined $res) {
#			write_log("$tool not installed!");
#		}
#	}
#	write_log("check the ganglia");
	$failed = 0;
	#write_log("Check the Gmond rpm package");
	my $gmond_count = `rpm -qa|grep gmond|wc -l`;
	if ( ( $? >> 8 ) != 0 or $gmond_count != 1 ){
		write_log($log_err, "the ganglia's rpm has problem!");
		($failed == 0) and $failed = 1;
	}
	my $gmond_version = `rpm -qa|grep gmond`;
	chomp $gmond_version;
	#write_log("Check the Gmond version");
	write_log($log_err, "the ganglia's version is $gmond_version not ganglia-gmond-3.2.0-1") unless $gmond_version eq "ganglia-gmond-3.1.7-1_qihoo";
	my $gmond = `sudo /sbin/service gmond status|grep "is running"`;
	if ( ( $? >> 8 ) != 0 or not defined ($gmond)){
		write_log($log_err, "ganglia is not running!");
		my $msg = "ganglia is not running!";
		alarm_monitors($msg, 1);
		($failed == 0) and $failed = 1;
	}
	#write_log("Check the gmond.conf");
	if ( -e "/etc/ganglia/gmond.conf" ) { 
		#write_log("gmond.conf is exist");
		my $send_metadata_interval = `cat /etc/ganglia/gmond.conf|grep send_metadata_interval`;
		chomp $send_metadata_interval;
		if ($send_metadata_interval ne "  send_metadata_interval = 60 /*secs */") {
			write_log($log_err, "the send_metadata_interval was wrong!");
			my $msg ="err send_mt_inter value!";
			alarm_monitors($msg, 1);
			($failed == 0) and $failed = 1;
		}
	}else{
		my $msg = "gmond.conf not defined!";
		alarm_monitors($msg, 1);
		write_log($log_err, "gmond.conf does not exist");
		($failed == 0) and $failed = 1;
	}
	#my $chkcfg_gmond = `/sbin/chkconfig --list gmond`;
	#chomp $chkcfg_gmond;
	#write_log("Check the chkconfig of gmond");
	#if ( $chkcfg_gmond ne "gmond              0:¹Ø±Õ  1:¹Ø±Õ  2:ÆôÓÃ  3:ÆôÓÃ  4:ÆôÓÃ  5:ÆôÓÃ  6:¹Ø±Õ" and $chkcfg_gmond ne "gmond	0:off	1:off   2:on    3:on    4:on    5:on    6:off"){
	my $gmond_chkcfg_level = `/sbin/chkconfig --list gmond | awk '{print \$5}' | awk -F ":" '{print \$2}' 2>/dev/null`;
	chomp $gmond_chkcfg_level;
	if ($gmond_chkcfg_level ne "on") {
		my $msg = "gmond chkconfig is on!";
		alarm_monitors($msg, 1);
		write_log($log_err, "gmond chkconfig is wrong!");
		($failed == 0) and $failed = 1;
	}
	if ($failed == 0) {  
#		write_log("check ganglia success!\n");
	} else {
#		write_log("check ganglia failed!\n");
	}
}

sub check_lvs_comm_tool_version()
{
#	write_log("checking lvs tool version");
	$failed = 0;
	my @tool_tb = (
		"keepalived",
		"ipvsadm",
	);
	#for my $tool (keys %tool_tb) {
	foreach my $tool (@tool_tb) { 
                my $res;
                if ($tool =~ /ipvsadm/)  {
                        $res = `$tool -v | awk '{print \$2}' | sed 's/v\\|V//g' 2>/dev/null`;
                } elsif ($tool =~ /keepalived/) {
			$res = `$tool -v 2>&1 | awk '{print \$2}' | sed 's/v\\|V//g' 2>/dev/null`;
		}
                chomp $res;
		if ($res ne $lvs_tool_table{$tool}) {
			write_log($log_warning, "old $tool version $res, please install v$lvs_tool_table{$tool}");	
			($failed == 0) and $failed = 1;
		}
	}
	if ($failed == 0) { 
#		write_log("check lvs tool version success!\n");
	} else {
#		write_log("check lvs tool version failed!\n");
	}
}

sub check_nat_comm_tool_version()
{
#	write_log("checking nat tool version");
	$failed = 0;
	my @tool_tb = (
		"keepalived",
		"ipvsadm",
	);
	#for my $tool (keys %tool_tb) {
	foreach my $tool (@tool_tb) { 
		my $res;
                if ($tool =~ /ipvsadm/)  {
                        $res = `$tool -v | awk '{print \$2}' | sed 's/v\\|V//g' 2>/dev/null`;
                } elsif ($tool =~ /keepalived/) {
			$res = `$tool -v 2>&1 | awk '{print \$2}' | sed 's/v\\|V//g' 2>/dev/null`;
                }
                chomp $res;
		if ($res ne $nat_tool_table{$tool}) {
			write_log($log_warning, "old $tool version $res, please install v$nat_tool_table{$tool}");	
			($failed == 0) and $failed = 1;
		}
	}
	if ($failed == 0) { 
#		write_log("check nat tool version success!\n");
	} else {
#		write_log("check nat tool version failed!\n");
	}
}

sub check_lvs_module()
{
#	write_log("checking lvs modules version");
	$failed = 0;
	my $version = `cat /sys/module/ip_vs/version`;
	chomp $version;
	if ($version ne $lvs_modules_table{"ip_vs"}) {
		write_log($log_warning, "old lvs module version $version, please install $lvs_modules_table{\"ip_vs\"}");
		($failed == 0) and $failed = 1;
	}
	if ($failed == 0) { 
#		write_log("check lvs modules success!\n");
	} else {
#		write_log("check lvs modules failed!\n");
	}
}

sub check_nat_module()
{
#	write_log("checking nat modules version");
	$failed = 0;
	my $version = `cat /sys/module/ip_vs/version`;
	chomp $version;
	if ($version ne $nat_modules_table{"ip_vs"}) {
		write_log($log_warning, "old nat module version $version, please install $nat_modules_table{\"ip_vs\"}");
		($failed == 0) and $failed = 1;
	}
	if ($failed == 0) { 
#		write_log("check nat modules success!\n");
	} else {
#		write_log("check nat modules failed!\n");
	}
}

sub check_cluster_tool_version()
{
#	write_log("checking cluster tool version");
	$failed = 0;
	my @tool_tb = (
		"zebra",
		"ospfd",
		"keepalived",
		"ipvsadm",
	);
	#for my $tool (keys %tool_tb) {
	foreach my $tool (@tool_tb) { 
		my $res;
		if ($tool =~ /zebra/ or $tool =~ /ospfd/) {
		    	$res = `$tool -v | grep "version" 2>&1 | awk '{print \$3}' | sed 's/v\\|V//g' 2>/dev/null`;
		} elsif ($tool =~ /ipvsadm/)  {
		    	$res = `$tool -v | awk '{print \$2}' | sed 's/v\\|V//g' 2>/dev/null`;
		} elsif ($tool =~ /keepalived/) {
			$res = `$tool -v 2>&1 | awk '{print \$2}' | sed 's/v\\|V//g' 2>/dev/null`;
		}
		chomp $res;
		if ($res ne $lvs_tool_table{$tool}) {
			write_log($log_warning, "old $tool version $res, please install v$lvs_tool_table{$tool}");	
			($failed == 0) and $failed = 1;
		}
	}
	if ($failed == 0) { 
#		write_log("check cluster tool version success!\n");
	} else {
#		write_log("check cluster tool version failed!\n");
	}
}
	
sub check_comm_process()
{
#	write_log("checking common process");
	$failed = 0;

	my @comm_proc_tb = (
#	"keepalived",
		"dl_lvsm.pl",
		"supervise /home/lvs/alarm",
	);
	foreach my $process (@comm_proc_tb) {	
		my $res = `ps axf 2>&1 | grep "$process" | wc -l 2>/dev/null`;
		chomp $res;
		$res -= 2;
		if ($res ne 4) {
		    my $msg = "keepalived num: $res, expect 4!";
		    alarm_monitors($msg, 1);
		}
		if ($res ne $process_table{$process}) {
			write_log($log_err, "unexpected process number of $process = $res, expected $process_table{$process}");
			($failed == 0) and $failed = 1;
		}
	}
	if ($failed == 0) { 
#		write_log("check common process success!\n");
	} else {
#		write_log("check common process failed!\n");
	}
}

sub check_cluster_process()
{
#	write_log("checking cluster process");
	$failed = 0;

	my @proc_tb = (
		"zebra",
		"ospfd",
	);
	foreach my $process (@proc_tb) {	
		my $res = `ps axf 2>&1 | grep "$process" | wc -l 2>/dev/null`;
		chomp $res;
		$res -= 2;
		if ($res ne $process_table{$process}) {
			my $msg = "$process num: $res, expect $process_table{$process}!";
			alarm_monitors($msg, 1);
			write_log($log_err, "unexpected process number of $process = $res, expected $process_table{$process}");
			($failed == 0) and $failed = 1;
		}
	}
	if ($failed == 0) { 
#		write_log("check cluster process success!\n");
	} else {
#		write_log("check cluster process failed!\n");
	}
}

sub check_logrotate()
{
#	write_log("checking logrotate");
	$failed = 0;
	my @rotate = (
		"/etc/logrotate.d/lvs_rotate",
		"/etc/security/limits.d/def.conf",
	);
	foreach my $file (@rotate) {
		my $md5 = `md5sum $file 2>&1 | awk -F " " '{print \$1}' 2>/dev/null`;
		chomp $md5;
		if ($md5 ne $lvs_md5_table{$file}) {
			write_log($log_err, "md5 err for $file, 4 spaces tab or 8 spaces tab)");
			my $base_name = `basename $file`;
			chomp $base_name;
			my $msg = "$base_name md5 err!";
			alarm_monitors($msg, 1);
			($failed == 0) and $failed = 1;
		}
	}
#	my $res = `cat /etc/syslog.conf | grep "kern\.debug\\s*-\/data1\/bignat\/log" 2>/dev/null`;
#	if ( ! -e $logrotate) {
#		write_log("cat not find $logrotate!\n");
#		($failed eq 0) and $failed = 1;
#	} else {
#		my $cont = `cat $logrotate 2>/dev/null`;
#		if ($cont =~ /\/var\/log\/messages.bak \/var\/log\/dmesg.bak\s*\{/../\}/) {
#			;
#		} else {
#			($failed eq 0) and $failed = 1;
#			write_log("messages.bak and dmesg.bak logrotate not defined in $logrotate");
#		}
#	}
#	if ($lvs_mode =~ /^nat$|^NAT$/) {
#		$cont = `cat /etc/logrotate.d/natlog 2>/dev/null`;
#		if ($cont =~ /\/data1\/bignat\/log\s*\{/../\}/) {	
#			;
#		} else {
#			($failed eq 0) and $failed = 1;
#			write_log("natlog logrotate not defined in /etc/logrotate.d/natlog");
#		}
#	}
	if ($failed == 0) { 
#		write_log("check logrorate success!\n");
	} else {
#		write_log("check logrorate failed!\n");
	}
}

sub check_nat_especial_conf()
{

#	write_log("checking syslog config");
	$failed = 0;
	my @syslog = (
		"/etc/syslog.conf",
#	"/etc/logrotate.d/natlog",
	);
	foreach my $file (@syslog) {
		my $md5 = `md5sum $file 2>&1 | awk -F " " '{print \$1}' 2>/dev/null`;
		chomp $md5;
		if ($md5 ne $lvs_md5_table{$file}) {
			my $base_name = `basename $file`;
			chomp $base_name;
			my $msg = "$base_name md5 err!";
			alarm_monitors($msg, 1);
			write_log($log_err, "md5 err for $file");
			($failed == 0) and $failed = 1;
		}
	}
#	my $res = `cat /etc/syslog.conf | grep "kern\.debug\\s*-\/data1\/bignat\/log" 2>/dev/null`;
#	if ($? != 0) {
#		write_log("asynchronous kern.debug r/w not defined in /etc/syslog.conf");
#		($failed eq 0) and $failed = 1;
#	}
#	$res = `cat /etc/syslog.conf 2>&1 | grep "\*\.info;mail\.none;authpriv\.none;cron\.none\\s*\-\/var\/log\/messages" 2>/dev/null`;
#	if ($? != 0) {
#		write_log("asynchronous messages r/w not defined in /etc/syslog.conf");
#		($failed eq 0) and $failed = 1;
#	}
	if ($failed == 0) {
#		write_log("check syslog config success!\n");
	} else {
#		write_log("check syslog config failed!\n");
	}
}

sub check_cluster_mode()
{
#	write_log("checking clustering mode");
	my $failed = 0;
	my $res = `cat /usr/local/etc/keepalived/keepalived.conf | grep "cluster_mode" 2>/dev/null`;
	if ($? != 0) {
		my $msg = "cluster not defined in keepalived!";
		alarm_monitors($msg, 1);
		write_log($log_err, "check cluster mode failed in /usr/local/etc/keepalived/keepalived.conf");
		($failed == 0) and $failed = 1;	
	}
	if ($failed == 0) {
#		write_log("check cluster mode success");
	} else {
#		write_log("check cluster mode failed!\n");
	} 
}

sub init_lvs_para()
{
	my @info = split(/ /, `cat $rc_local | grep "\/etc\/rc.d\/lvs_rc.local" 2>/dev/null`);
	$lvs_mode = @info[2];
	$l3_through = @info[4];
	$syn_proxy = @info[6];
	open(FILE, ">$lvs_check_log") or die "Error: conld not read from $lvs_check_log, program halting.";
	my $tmp = `cat /etc/issue | grep "CentOS"`;
	chomp $tmp;
	if ($tmp =~ /^CentOS\s+release\s+(.*)\s+\(Final\)/) {
		$sys_ver=$1;
	}
	if ($sys_ver =~ /5\.4/) {
		$modprobe_conf = "/etc/modprobe.conf";
	} elsif ($sys_ver =~ /6\.2/) {
		$modprobe_conf = "/etc/modprobe.d/modprobe.conf";
	}
}

sub init_lvs_check()
{
	init_lvs_para();
}

sub fin_lvs_check()
{	
	close(FILE);
}

sub check_dns()
{
	my $ret = `ping -c 2 smarte.corp.qihoo.net -W 3`;
	if ($ret =~ /unknown host/ || $ret !~ /time=/) {
		write_log($log_err, "Ping smarte.corp.qihoo.net failed, please check");
	} 
	
	$ret = `ping -c 2 ntp1.qihoo.net -W 3`;
	if ($ret =~ /unknown host/ || $ret !~ /time=/) {
		write_log($log_err, "Ping ntp1.qihoo.net failed, please check");
	} 
	
}

init_lvs_check();

write_log($log_info, "lvs_mode:$lvs_mode | l3_through:$l3_through | syn_proxy:$syn_proxy");

if ($lvs_env_check_version ne 1.1) 
{
    write_log($log_warning, "Using old version of lvs_env_check");
}

check_mem();
check_disk();
check_nic();
check_net();
check_alarm();
#check_ganglia();
check_comm_process();
check_logrotate();
check_crontab($lvs_mode);
#check_keepalived();
check_dns();

switch: {
	$lvs_mode =~ /^lvs_nat$|^LVS_NAT$/ and do {
		check_system($lvs_kern_ver);
		check_lvs_nat();
		check_lvs_comm_tool_version();
		check_lvs_nat_conf_file();
		check_monitor();
		check_lvs_module();
	}, last;
	$lvs_mode =~ /^lvs_dr$|^LVS_DR$/ and do {
		check_system($lvs_kern_ver);
		check_lvs_dr();
		check_lvs_comm_tool_version();
		check_lvs_dr_conf_file();
		check_monitor();
		check_lvs_module();
	}, last;
	$lvs_mode =~ /^nat$|^NAT$/ and do {
		check_system($nat_kern_ver);
		check_nat();
		check_nat_comm_tool_version();
		check_nat_conf_file();
		check_nat_monitor();
		check_nat_especial_conf();
		check_nat_module();
	}, last;
	$lvs_mode =~ /^lvs_cluster$|^LVS_CLUSTER$/ and do {
		#check_lvs_nat();
		check_cluster_system($lvs_kern_ver);
		check_lvs_cluster();
		check_lvs_cluster_conf_file();
		check_monitor();
		check_vip_list();
		check_cluster_tool_version();
		check_cluster_process();
		check_cluster_mode();
		check_lvs_module();
	}, last;
	$lvs_mode =~ /.*/ and do {
		write_log($log_err, "unknown lvs mode $lvs_mode, please check!");
	}, last;
}

