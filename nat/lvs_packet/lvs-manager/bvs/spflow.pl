#!/usr/bin/perl

my $spflow_main = "/home/lvs/spflow";
#my $start_cmd = "nohup /sbin/supervise /home/lvs/spflow > nohup.out 2>&1 &";
my $start_cmd = "sudo -u '#`id -u root`' bash -c 'nohup /sbin/supervise /home/lvs/spflow >> nohup.out 2>&1 &'";
my $stop_cmd = "kill -9";

require("/home/bvs-manager/bvs/common.pl");

my %spflow_cmd = (
    'start' =>  \&start_spflow,
    'stop'  =>  \&stop_spflow,
);

my %status_code = (
    '102'   =>  "Invalid option",
);

sub start_spflow()
{
    chdir $spflow_main;
	system ("$start_cmd");
	print "start spflow Success\n";
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

sub stop_spflow()
{
    kill_process "supervise /home/lvs/spflow";
    kill_process "/home/lvs/spflow/pflow";
	print "Stop spflow Success\n";
    exit(0);
}

if (defined($ARGV[0])) {
    if (defined($spflow_cmd{$ARGV[0]})) {
		$spflow_cmd{$ARGV[0]}();
    } else {
		err_exit("$status_code{'102'}: $ARGV[0]", 102);
    }
}

