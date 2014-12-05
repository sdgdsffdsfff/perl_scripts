#!/usr/bin/perl

my $packet = "lvs_packet.tar.gz";
my $mode = $ARGV[0];
my $run_nic = "auto_nic.pl";
`curl -o $run_nic http://218.30.117.221/lvs_package/$run_nic`;
`chmod +x $run_nic`;
if ($mode =~ /nat/) {
`curl -o $packet http://218.30.117.221/lvs_package/nat_packet.tar.gz`;
} elsif ($mode =~ /lvs/) {
`curl -o $packet http://218.30.117.221/lvs_package/lvs_cluster_packet.tar.gz`;
} else {
	print "Wrong argv, Input lvs or nat\n";
}

# lvs_install.conf file must be auto complete BEFORE run lvs_install.sh

## Start to run nic shift
# `./$run_nic`;
# sleep(5);
# `tar xvf $packet`;
# `cd $packet && ./lvs_install.sh`;
