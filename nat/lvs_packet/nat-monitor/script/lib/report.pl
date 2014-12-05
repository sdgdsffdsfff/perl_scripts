#!/usr/bin/perl

use LWP;

$gsms="hadoop_dxt_logsget";
$gemail="hadoop_dxt_logsget_emailonly";

sub doAlarm {
        my $ua = LWP::UserAgent->new;
	my $hostname = `hostname`;
        my $title   = "[".$hostname."] ".$_[0];
        my $content = "[".$hostname."] ".$_[1];
	my $dosms = $_[2];
	
	$baseurl = "http://alarms.ops.qihoo.net:8360/intfs/alarm_intf";
	if ($dosms == 1){
                my $url = $baseurl."?group_name=$gsms&&subject=$title&content=$content";
                $response = $ua->get($url);
        }else{
		my $url = $baseurl."?group_name=$gemail&&subject=$title&content=$content";
		$response = $ua->get($url);
	}
}

