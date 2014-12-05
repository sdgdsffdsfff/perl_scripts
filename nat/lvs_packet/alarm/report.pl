#!/usr/bin/perl

use LWP;
use File::Basename;

$MAIN_DIR=dirname($0);

sub get_vip($)
{
    my $content = $_[0];
    if ($content =~ /\[(.+)\]\s+RS\s+\[(.+)\]\s+for\s+VS\s+\[(.+):\d+\]/) {
	return $3;
    }
    if ($content =~ /\[(.+)\]\s+VS\s+\[(.+):\d+\]\s+/) {
	return $2;
    }
}

sub get_localtime
{    
    my $date;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon ++;  
    $date = sprintf("%02d/%02d %02d:%02d", $mday, $mon, $hour, $min);
    return $date;
}

sub doAlarm() {
	my $ua = LWP::UserAgent->new;
	$ua->timeout(5);
	my $hostname = `hostname`;
	$hostname =~ s/\.qihoo\.net$//g;
	chomp($hostname);
	my $local_time = get_localtime();
	my $title   = "[".$hostname."] ".$_[0];
	my $content = "[".$hostname." $local_time] ".$_[1];
	my $dosms = $_[2];
	my ($alarm_service) = $_[3];
	my $i = 0;
	my $vip = get_vip($content);
	my @info;

	if ($vip and @{$alarm_service->{$vip}}) {
	    @info = @{$alarm_service->{$vip}};
	    if ($info[0]) {
		$title =~ s/$vip/$info[0]/g;
		$content =~ s/$vip/$info[0]/g;
	    }
	    @host_info=split /\./,$hostname;
            $title =~ s/$hostname/@host_info[2]/g;
	}

	$baseurl = "http://alarms.ops.qihoo.net:8360/intfs/alarm_intf";
	if ($dosms == 1) {
		my @sms_list = split(/\|/, $info[1]); 
		if ($#sms_list < 0) {
		    for ($i = 0; $i < @sms_grp; $i++) {
			my $url = $baseurl."?group_name=$sms_grp[$i]&&subject=$title&content=$content";
			$response = $ua->get($url);
			if (not $response->is_success) {
			    print "get $url failed: ", $response->status_line;
			    print "\n";
			}
		    }
		} else {
		    for ($i = 0; $i <= $#sms_list; $i++) {
			my $url = $baseurl."?group_name=$sms_list[$i]&&subject=$title&content=$content";
			$response = $ua->get($url);
			if (not $response->is_success) {
			    print "get $url failed: ", $response->status_line;
			    print "\n";
			}
		    }
		}
	} else {
		my @email_list = split(/\|/, $info[2]);
		if ($#email_list < 0) { 
		    for ($i = 0; $i < @email_grp; $i++) {
			my $url = $baseurl."?group_name=$email_grp[$i]&&subject=$title&content=$content";
			$response = $ua->get($url);
			if (not $response->is_success) {
			    print "get $url failed: ", $response->status_line;
			    print "\n";
			}
		    }
		} else {
		    for ($i = 0; $i <= $#email_list; $i++) {
			my $url = $baseurl."?group_name=$email_list[$i]&&subject=$title&content=$content";
			$response = $ua->get($url);
			if (not $response->is_success) {
			    print "get $url failed: ", $response->status_line;
			    print "\n";
			}
		    }
		}
	}	
}
