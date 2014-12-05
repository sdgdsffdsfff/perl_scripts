#kickstart option
auth  --useshadow  --enablemd5 
#bootloader --append "console=tty0 console=ttyS0,115200n8" # --location=mbr
bootloader --append "console=tty0 console=hvc0" --location=mbr
zerombr
text
firstboot --disable
key --skip
keyboard us
lang en_US
firewall --disabled
authconfig --useshadow  --enablemd5
rootpw --iscrypted $1$pBFUP9Cl$duiikAVB5F2nUCEo6W8Pk1
network --bootproto=dhcp --device=eth0 --onboot=on
#install tree
#url --url http://download.englab.nay.redhat.com/pub/rhel/released/RHEL-6/Beta-2/Server/i386/os/
url --url http://alpha.nay.redhat.com/tree/RHEL6.1-20110224.2-Server/i386/
#url --url http://10.66.92.96/tree/RHEL6.0/i386/
clearpart --all --initlabel 
autopart
selinux --disabled
#system time 
timezone --isUtc Asia/Shanghai
install
skipx
poweroff
#shell scripts after install in the chroot environment
%packages
@Core
@Base
@X Window System
@Development
NetworkManager
