install
cdrom
key --skip
lang en_US.UTF-8
keyboard us
skipx
network --device eth0 --bootproto dhcp --onboot yes
rootpw redhat 
firewall --disabled
authconfig --enableshadow --enablemd5
selinux --enforcing
timezone --utc America/New_York
bootloader --location=mbr --append="console=ttySG0"
text
#cmdline
#poweroff
reboot
zerombr
clearpart --all --initlabel
autopart
%packages --ignoremissing
@development-tools
@development-libs
libxml2-python
ntp
expect
pyOpenSSL
emacs
vim-enhanced
unifdef
