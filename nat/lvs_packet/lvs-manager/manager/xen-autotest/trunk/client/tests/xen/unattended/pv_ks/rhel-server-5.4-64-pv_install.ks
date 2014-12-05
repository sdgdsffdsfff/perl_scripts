#kickstart option
auth  --useshadow  --enablemd5 
#bootloader --append "console=tty0 console=ttyS0,115200n8" --location=mbr
bootloader --append --location=mbr
zerombr
text
firstboot --disable
key 49af-8941-4d14-7589
keyboard us
lang en_US
firewall --disabled
authconfig --useshadow  --enablemd5
rootpw --iscrypted $1$pBFUP9Cl$duiikAVB5F2nUCEo6W8Pk1
network --bootproto=dhcp --device=eth0 --onboot=on
#install tree
#nfs --server=10.66.71.201 --dir=/pub/rhel/nightly/RHEL5.5-Server-20100110.nightly/tree-x86_64/
#url --url http://download.englab.nay.redhat.com/pub/rhel/nightly/RHEL5.5-Server-latest/tree-x86_64/
url --url http://download.englab.nay.redhat.com/pub/rhel/released/RHEL-5-Server/U4/x86_64/os/
#url --url=http://download.englab.nay.redhat.com/pub/rhel/nightly/RHEL5.5-Server-20100110.nightly/tree-x86_64/
#url --url=http://download.englab.nay.redhat.com/nightly/latest-RHEL5.5-Server/tree-x86_64/
#user root password "redhat"
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
@base
@development-libs
@development-tools
