install
cdrom
text
lang en_US.UTF-8
langsupport --default=en_US.UTF-8 en_US.UTF-9
keyboard us
rootpw redhat
firewall --disabled
selinux --disabled
firstboot --disable
authconfig --enableshadow --passalgo=md5
bootloader --location=mbr --append="rhgb quiet"
timezone  America/New_York
network --bootproto=dhcp --device=eth0 --onboot=on
#install tree
url --url http://download.englab.nay.redhat.com/pub/rhel/released/RHEL-4/U8/AS/i386/tree/
skipx
clearpart --all --initlabel 
autopart
poweroff
%packages
@base
@development-libs
@development-tools
