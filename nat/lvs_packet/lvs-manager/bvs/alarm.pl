#!/usr/bin/perl

my $alarm_main = "/home/lvs/alarm";
#my $start_cmd = "nohup /sbin/supervise /home/lvs/alarm > nohup.out 2>&1 &";
my $start_cmd = "sudo -u '#`id -u root`' bash -c 'nohup /sbin/supervise /home/lvs/alarm >> nohup.out 2>&1 &'";
my $stop_cmd = "kill -9";

require("/home/bvs-manager/bvs/common.pl");

my %alarm_cmd = (
    'start' =>  \&start_alarm,
    'stop'  =>  \&stop_alarm,
);

my %status_code = (
    '102'   =>  "Invalid option",
);

sub start_alarm()
{
    chdir $alarm_main;
	system ("$start_cmd");
	print "start alarm Success\n";
	exit (0);
}

sub kill_process($)
{
    my $process = $_[0];
    my @pids = `ps axf | grep "$process" | grep -v "grep" | awk '{print \$1}' 2> /dev/null`;
    foreach my $pid (@pids) {
		`$stop_cmd $pid 2>&1 /dev/null`;
    }
}

sub stop_alarm()
{
    kill_process "supervise /home/lvs/alarm";
    kill_process "dl_lvsm.pl conf";
	print "Stop alarm Success\n";
    exit(0);
}

if (defined($ARGV[0])) {
    if (defined($alarm_cmd{$ARGV[0]})) {
		$alarm_cmd{$ARGV[0]}();
    } else {
		err_exit("$status_code{'102'}: $ARGV[0]", 102);
    }
}

