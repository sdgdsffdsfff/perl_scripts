install
lang en_US
langsupport --default=en_US
keyboard us
mouse generic3ps/2
timezone America/New_York
rootpw redhat
reboot
bootloader --location=mbr  --append='rhgb quiet'
clearpart --all --initlabel 
autopart
auth  --useshadow  --enablemd5 
firewall --disabled 
network --bootproto=dhcp --device=eth0
url --url http://download.englab.nay.redhat.com/pub/rhel/released/RHEL-3/U9/AS/x86_64/tree/
skipx
#firstboot --disable
%packages --resolvedeps
@ Development Tools
@ Administration Tools
@ System Tools
