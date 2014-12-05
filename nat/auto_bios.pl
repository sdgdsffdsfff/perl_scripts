#!/usr/bin/perl

my $system_info = `/usr/sbin/dmidecode -s system-product-name`;
chomp($system_info);

sub NF5270M3_get_bios
{
	my $output = $_[0];
	my $input = $_[1];

	my $line;
	open (FILE, "./$output") || die ("Could not open standard_bios");
	open (NEWFILE, ">./$input") || die ("Could not open $input");
	while ($line = <FILE>) {
RETRYE:
		chomp($line);
		#print "$line\n";
		if ($line =~ /Hyper-threading/ || $line =~ /Adjacent Cache Line Prefetch/ || $line =~ /Hardware Prefetcher/ || $line =~ /DCU Streamer Prefetcher/ || $line =~ /Intel Virtualization Technology/) {
			print NEWFILE ("$line\n");
			while ($line = <FILE>) {
				chomp($line);
				if ($line !~ /Setup Question/ ) {
					if ($line =~ /Options/) {
						#print NEWFILE ("$line\n");
						#$line = <FILE>;
						print NEWFILE ("Options =\*\[00\]Disabled  // Move \"\*\" to the desired Option\n");
						$line = <FILE>;
						print NEWFILE ("         \[01\]Enabled\n");
					} else {
						print NEWFILE ("$line\n");
					}	
				} else {
					goto RETRYE;
				}	
			}
		} elsif ($line =~ /Energy Performance/) {
			print NEWFILE ("$line\n");
			while ($line = <FILE>) {
				chomp($line);		
				if ($line !~ /Setup Question/ ) {
					if ($line =~ /Options/) {
						#print NEWFILE ("$line\n");
						#$line = <FILE>;
						print NEWFILE ("Options =\*\[00\]Performance        // Move \"\*\" to the desired Option\n");
						$line = <FILE>;
						print NEWFILE ("         \[07\]Balanced Performance\n");
						$line = <FILE>;
						print NEWFILE ("         \[0B\]Balanced Energy\n");
						$line = <FILE>;
						print NEWFILE ("         \[0F\]Energy Efficient\n");
					} else {
						print NEWFILE ("$line\n");
					}	
				} else {
					goto RETRYE;
				}	
			}
		} elsif ($line =~ /Active Processor Cores/) {
			print NEWFILE ("$line\n");
			while ($line = <FILE>) {
				chomp($line);
				if ($line !~ /Setup Question/ ) {
					if ($line =~ /Options/ && $line !~ /\*\[/ && $line =~ /All/) {
						#print NEWFILE ("$line\n");
						#$line = <FILE>;
						$line =~ s/\[/\*\[/g;                                    
                                                print NEWFILE ("$line\n"); 
						#print NEWFILE ("Options =\*\[00\]Disabled  // Move \"\*\" to the desired Option\n");
						#$line = <FILE>;
						#print NEWFILE ("         \[01\]Enabled\n");
					} elsif ($line !~ /Options/ && $line !~ /All/ && $line =~ /\*\[/) {
						$line =~ s/\*\[/\[/g;
						print NEWFILE ("$line\n");
					} else {
						print NEWFILE ("$line\n");
					}
				} else {
					goto RETRYE;
				}
			}
		} else {
			print NEWFILE ("$line\n");
		}

	}
	close(FILE);
	close(NEWFILE);
}

sub PowerEdge_R720_ajust
{
	if ( -d "/opt/dell") { 
		print "/opt/dell already exist, delete ...\n";
		`rm -rf /opt/dell`;
	} 
	if ( -e "./dell-tool.tar.gz") {
		print "dell-tool.tar.gz already exist, delete ...\n";
		`rm -f ./dell-tool.tar.gz`;
	} 
	if ( -e "./dell.tar.gz" ) {
		print "dell.tar.gz already exist, delete...\n";
		`rm -f ./dell.tar.gz`;
	}
	`curl -o dell-tool.tar.gz http://218.30.117.221/lvs_package/dell-tool.tar.gz`;
	`curl -o dell.r720.bios_tools.tgz http://218.30.117.221/lvs_package/dell.r720.bios_tools.tgz`;

	`tar xvf dell-tool.tar.gz 2>&1`;
	`tar xvf dell.r720.bios_tools.tgz 2>&1 && mv ./dell /opt/`;
	
	`rpm -i ./dell-tool/libsmbios-2.2.27-4.9.1.el6.x86_64.rpm`;
	`rpm -i ./dell-tool/srvadmin-omilcore-7.3.0-4.72.1.el6.x86_64.rpm`;
	`rpm -i ./dell-tool/smbios-utils-bin-2.2.27-4.9.1.el6.x86_64.rpm`;
	`rpm -i ./dell-tool/srvadmin-deng-7.3.0-4.13.2.el6.x86_64.rpm`;
	`rpm -i ./dell-tool/srvadmin-hapi-7.3.0-4.12.3.el6.x86_64.rpm`;
	`rpm -i ./dell-tool/srvadmin-isvc-7.3.0-4.21.4.el6.x86_64.rpm`;
	`rpm -i ./dell-tool/syscfg-4.3.0-4.33.4.el6.x86_64.rpm`;
	
	print "\n rpm install over....\n";
	
	my $ret = `/opt/dell/srvadmin/sbin/srvadmin-services.sh start`;

	$ret = `/opt/dell/toolkit/bin/syscfg --virtualization=Disabled ; /opt/dell/toolkit/bin/syscfg --turbomode=Disabled ; /opt/dell/toolkit/bin/syscfg --hwprefetcher=Disabled ; /opt/dell/toolkit/bin/syscfg --adjcacheprefetch=Disabled; /opt/dell/toolkit/bin/syscfg --dcustreamerprefetcher=Disabled; /opt/dell/toolkit/bin/syscfg --logicproc=Disabled; /opt/dell/toolkit/bin/syscfg --cstates=Disabled; /opt/dell/toolkit/bin/syscfg --ProcPwrPerf=MaxPerf; /opt/dell/toolkit/bin/syscfg --cpucore=All`;

	if ($ret !~ /Unable to connect data manager/) {
              print "BIOS ADJUST OVER : \n $ret \n\n";
        } else {
              print "ERROR MSG: $ret\n"
        }
}

my $res;
if ($system_info eq "NF5270M3") {
	print "NF5270M3 bios auto adjust....\n";
	my $link = `ls /lib/modules | grep el6.x86_64`;
	if ($link) {
		chomp($link);
		my $kernel = `ls /usr/src/kernels/ | grep el6.x86_64`;
		chomp($kernel);
		if ($link ne $kernel) {
			print "Ajust kernel soft link to /usr/src/kernels/$link\n";
			`mv /usr/src/kernels/$kernel /usr/src/kernels/$link`;
		}
		`curl  -o instool.tar.gz http://218.30.117.221/lvs_package/instool.tar.gz`;
		`tar xvf instool.tar.gz`;
		chdir "./instool";
		$res = `sudo ./instool.sh -bios info`;
		if ($res =~ /Only use in Inspur equipment/) {
			print "Unknow Error, MSG: Only use in Inspur equipment";
		} else {
			my $output = "bios_output";
			my $input = "bios_input";
			$res = `sudo ./instool.sh -bios output ./$output`;
			NF5270M3_get_bios($output, $input);
			$res = `sudo ./instool.sh -bios input ./$input`;
		}
	} else {
		$res = "ERROR: Can not get kernel under /lib/modules\n";
	}
	if ($res =~ /Script file imported successfully/) {
		print "BIOS ADJUST SUCCESS\n";
	} else {
		print "ERROR: $res\n";
	}
} elsif ($system_info eq "PowerEdge R720") {
	print "PowerEdge R720 bios auto ajust ....\n";
	PowerEdge_R720_ajust();

	#if ( not -e "/usr/lib64/libdchbas.so.7") {
	#	`ln -fs /opt/dell/srvadmin/lib64/libdchbas.so.7.3.0 /usr/lib64/libdchbas.so.7`;
	#}
	#if (not -e "/usr/lib64/libdchbas.so.7.3.0") {
	#	`ln -fs /opt/dell/srvadmin/lib64/libdchbas.so.7.3.0 /usr/lib64/libdchbas.so.7.3.0`;
	#}	
	#if (not -e "/usr/lib64/libdchipm.so.7") {
	#	`ln -fs /opt/dell/srvadmin/lib64/libdchipm.so.7 /usr/lib64/libdchipm.so.7`;
	#}
	##`/opt/dell/srvadmin/sbin/srvadmin-services.sh start`;
	
} else {
	print "NOT SURPPORT MACHINE\n"
}

