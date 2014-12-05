#!/bin/bash

base=$(pwd)
lvs_home=/home/lvs
lvs_inst_conf=$base/lvs_install.conf
user=lvsops
main_dir=/home/$user
keepalived_dir=/usr/local/etc/keepalived
ifcfg_dir=/etc/sysconfig/network-scripts/
#modprobe_conf=/etc/modprobe.conf

kernel_ver=
lvs_mode=
l3_through=1
syn_proxy=0
hostname=
ipvs_ver=
ospfd_ip=
ospfd_mask=
ospfd_gw=
ixgbe_nic_out=
ixgbe_nic_in=
ixgbe_nic_in_ip=
ixgbe_nic_in_mask=
ixgbe_nic_in_gw=
mgt_nic_out=
mgt_nic_out_ip=
mgt_nic_out_mask=
mgt_nic_out_gw=
mgt_nic_in=
mgt_nic_in_ip=
mgt_nic_in_mask=
mgt_nic_in_gw=
other_nics=

sys_ver=
syslog_conf=
modprobe_conf=

dns_table="bjt:220.181.127.173|220.181.127.240
	    ccc:123.125.74.57|123.125.74.58
	    ccp:58.68.225.101|115.182.38.173
	    cct:220.181.47.79|220.181.47.80,
	    dxt:115.182.38.173|115.182.38.240
	    hyb:220.181.156.252|220.181.156.247
	    lft:124.238.254.10|124.238.254.11
	    njt:202.102.97.225|202.102.97.226
	    qht:123.183.216.241|123.183.216.247
	    shgt:180.153.227.247|180.153.227.248
	    sjc:61.55.185.252|61.55.185.253
	    vjc:119.188.64.201|119.188.64.202
	    vnet:211.151.122.231|211.151.122.232
	    xjt:218.84.244.15|218.84.244.17
	    zwt:220.181.156.247|220.181.156.252
	    zzbc:182.118.20.199|182.118.20.200"

function lvs_init()
{
    kernel_ver=$(grep "^kernel_ver=" $lvs_inst_conf | awk -F "=" '{print $2}')
    lvs_mode=$(grep "^lvs_mode=" $lvs_inst_conf | awk -F "=" '{print $2}')
    l3_through=$(grep "^l3_through=" $lvs_inst_conf | awk -F "=" '{print $2}')
    syn_proxy=$(grep "^syn_proxy=" $lvs_inst_conf | awk -F "=" '{print $2}')
    hostname=$(grep "^hostname=" $lvs_inst_conf | awk -F "=" '{print $2}')
    ipvs_ver=$(grep "^ipvs_ver=" $lvs_inst_conf | awk -F "=" '{print $2}')
    ospfd_ip=$(grep "^ospfd_ip=" $lvs_inst_conf | awk -F "=" '{print $2}')
    ospfd_mask=$(grep "^ospfd_mask=" $lvs_inst_conf | awk -F "=" '{print $2}')
    ospfd_gw=$(grep "^ospfd_gw=" $lvs_inst_conf | awk -F "=" '{print $2}')
    ixgbe_nic_out=$(grep "^ixgbe_nic_out=" $lvs_inst_conf | awk -F "=" '{print $2}')
    ixgbe_nic_in=$(grep "^ixgbe_nic_in=" $lvs_inst_conf | awk -F "=" '{print $2}')
    ixgbe_nic_in_ip=$(grep "^ixgbe_nic_in_ip=" $lvs_inst_conf | awk -F "=" '{print $2}')
    ixgbe_nic_in_mask=$(grep "^ixgbe_nic_in_mask=" $lvs_inst_conf | awk -F "=" '{print $2}')
    ixgbe_nic_in_gw=$(grep "^ixgbe_nic_in_gw=" $lvs_inst_conf | awk -F "=" '{print $2}')
    mgt_nic_out=$(grep "^mgt_nic_out=" $lvs_inst_conf | awk -F "=" '{print $2}')
    mgt_nic_out_ip=$(grep "^mgt_nic_out_ip=" $lvs_inst_conf | awk -F "=" '{print $2}')
    mgt_nic_out_mask=$(grep "^mgt_nic_out_mask=" $lvs_inst_conf | awk -F "=" '{print $2}')
    mgt_nic_out_gw=$(grep "^mgt_nic_out_gw=" $lvs_inst_conf | awk -F "=" '{print $2}')
    mgt_nic_in=$(grep "^mgt_nic_in=" $lvs_inst_conf | awk -F "=" '{print $2}')
    mgt_nic_in_ip=$(grep "^mgt_nic_in_ip=" $lvs_inst_conf | awk -F "=" '{print $2}')
    mgt_nic_in_mask=$(grep "^mgt_nic_in_mask=" $lvs_inst_conf | awk -F "=" '{print $2}')
    mgt_nic_in_gw=$(grep "^mgt_nic_in_gw=" $lvs_inst_conf | awk -F "=" '{print $2}')
    other_nics=$(grep "^other_nics=" $lvs_inst_conf | awk -F "=" '{print $2}')
    sys_ver=$(cat /etc/issue | grep "CentOS" | awk '{print $3}')
    if [ "$sys_ver" == "6.2" ]
    then
	syslog_conf="/etc/rsyslog.conf"
	modprobe_conf="/etc/modprobe.d/modprobe.conf"
    else
	syslog_conf="/etc/syslog.conf"
	modprobe_conf="/etc/modprobe.conf"
    fi

    echo -e "kernel_ver:\t$kernel_ver"
    echo -e "lvs_mode:\t$lvs_mode"
    echo -e "l3_through:\t$l3_through"
    echo -e "syn_proxy:\t$syn_proxy"
    echo -e "hostname:\t$hostname"
    echo -e "ipvs_ver:\t$ipvs_ver"
    echo -e "ospfd_ip:\t$ospfd_ip"
    echo -e "ospfd_mask:\t$ospfd_mask"
    echo -e "ospfd_gw:\t$ospfd_gw"
    echo -e "ixgbe_nic_out:\t$ixgbe_nic_out"
    echo -e "ixgbe_nic_in:\t$ixgbe_nic_in"
    echo -e "ixgbe_nic_in_ip:\t$ixgbe_nic_in_ip"
    echo -e "ixgbe_nic_in_mask:\t$ixgbe_nic_in_mask"
    echo -e "ixgbe_nic_in_gw:\t$ixgbe_nic_in_gw"
    echo -e "mgt_nic_out:\t$mgt_nic_out"
    echo -e "mgt_nic_out_ip:\t$mgt_nic_out_ip"
    echo -e "mgt_nic_out_mask:\t$mgt_nic_out_mask"
    echo -e "mgt_nic_out_gw:\t$mgt_nic_out_gw"
    echo -e "mgt_nic_in:\t$mgt_nic_in"
    echo -e "mgt_nic_in_ip:\t$mgt_nic_in_ip"
    echo -e "mgt_nic_in_mask:\t$mgt_nic_in_mask"
    echo -e "mgt_nic_in_gw:\t$mgt_nic_in_gw"
    echo -e "other_nics:\t$other_nics"
    echo -e "sys_ver:\t$sys_ver"
    echo -e "syslog_conf:\t$syslog_conf"
    echo -e "modprobe_conf:\t$modprobe_conf"
}

function kernel_install()
{
    /bin/tar zxf kernel-$kernel_ver.tgz
#    cd kernel-$kernel_ver
    kernel_dir=$base/kernel-$kernel_ver/
    /bin/rm -rf /lib/modules/$kernel_ver
    /bin/cp -rf $kernel_dir/$kernel_ver /lib/modules/
    [ -d firmware ] && /bin/rm -rf /lib/firmware && /bin/cp -rf firmware /lib/
    /bin/cp -rf $kernel_dir/System.map-$kernel_ver $kernel_dir/vmlinuz-$kernel_ver /boot
    
    mv /lib/modules/$kernel_ver/kernel/net/netfilter/ipvs /lib/modules/$kernel_ver/kernel/net/netfilter/ipvs_old
    mkdir -p /lib/modules/$kernel_ver/kernel/net/netfilter/ipvs
    /bin/cp -rf $base/ipvs_$ipvs_ver/*.ko /lib/modules/$kernel_ver/kernel/net/netfilter/ipvs/
    rm -rf /lib/modules/$kernel_ver/modules.dep.bin
    sed -i 's:ipvs_old:ipvs:g' /lib/modules/$kernel_ver/modules.dep
    new-kernel-pkg -v --mkinitrd --depmod --install $kernel_ver
    sed -i 's/default=.*/default=0/g' /boot/grub/grub.conf
#    cd -
}

function install_comm()
{
#    tar xvf ganglia_rpm.tar
#    rpm -ivh *.rpm
    logrotate_conf_path=/usr/local/etc/logrotate/
    [ ! -d $lvs_home ] && mkdir -p $lvs_home
    [ -d $lvs_home/alarm ] && /bin/rm -rf $lvs_home/alarm
    [ ! -d $logrotate_conf_path ] && mkdir -p $logrotate_conf_path
    /bin/cp -rf $base/alarm $lvs_home 
    /bin/cp -rf $base/lvs_env_check.pl $lvs_home
    /bin/cp -rf $base/lvs_status.pl $lvs_home
    /bin/cp -rf $base/set_irq_affinity.sh $lvs_home
    /bin/cp -rf $base/lvs_rc.local /etc/rc.d/
    /bin/cp -rf $base/lvs_rotate /etc/logrotate.d/
    /bin/cp -rf $base/lvs_rotate.conf $logrotate_conf_path
    /bin/cp -rf $base/def.conf /etc/security/limits.d/
    /bin/cp -rf $base/genhash /sbin
    /bin/cp -rf $base/ipvsadm /sbin
    /bin/cp -rf $base/keepalived /sbin
    /bin/cp -rf $base/supervise /sbin
    cd $base/lvs-manager
    ./install.sh bvs
    cd $base
    chmod 777 -R $lvs_home/alarm
    tar xvf Config-Simple-4.59.tar.gz 1>/dev/null && tar xvf logrotate-3.8.7.tar.gz 1>/dev/null
    cd $base/Config-Simple-4.59 && perl Makefile.PL 1>/dev/null && make 1>/dev/null && make install 1>/dev/null
    yum -y install popt-devel 1>/dev/null
    cd $base/logrotate-3.8.7 && make 1>/dev/null && make install 1>/dev/null
    cd $base
    chown -R root:root $logrotate_conf_path &&  chmod 644 -R $logrotate_conf_path 
}   


function install_lvs()
{
    [ -d $lvs_home/monitor ] && /bin/rm -rf $lvs_home/monitor
    /bin/cp -rf $base/monitor $lvs_home
}

function install_nat()
{
    [ -d $lvs_home/monitor ] && /bin/rm -rf $lvs_home/monitor
    /bin/cp -rf $base/nat-monitor $lvs_home/monitor
    /bin/cp -rf $base/natlog /etc/logrotate.d/
    /bin/cp -rf $base/syslog.conf $syslog_conf
}   

function install_cluster()
{
    [ -d $lvs_home/monitor ] && /bin/rm -rf $lvs_home/monitor
    /bin/cp -rf $base/monitor $lvs_home
    /bin/cp -rf $base/ospfd zebra /sbin/
    /bin/cp -rf $base/zebra.conf /usr/local/etc/
    /bin/cp -rf $base/ospfd.conf /usr/local/etc/
    sed -i "s/ ospf router-id 10.50.99.18/ ospf router-id $ospfd_ip/g" /usr/local/etc/ospfd.conf
    sed -i "s/ network 10.50.99.17\/29 area 0.0.0.14/ network $ospfd_gw\/$ospfd_mask area $ospfd_gw/g" /usr/local/etc/ospfd.conf
    sed -i "s/ network 220.181.156.0\/24 area 0.0.0.14/ area $ospfd_gw stub no-summary/g" /usr/local/etc/ospfd.conf

#    cd lvs-manager
#    ./install.sh bvs
#    cd -
}

function ganglia_config()
{
    gmond_conf=/etc/ganglia/gmond.conf
    sed -i 's/send_metadata_interval = 0/send_metadata_interval = 60/g' $gmond_conf
    key1=$(echo "$hostname" | awk -F "." '{print $1}' | sed 's/[0-9]//g')
    key2=$(echo "$hostname" | awk -F "." '{print $2}')
    idc=$(echo "$hostname" | awk -F "." '{print $3}')
    lvs_id=$key2.$key1.$idc
    sed -i "s/name = \"unspecified\"/name = \"$lvs_id\"/g" $gmond_conf 
}

function var_log_rebuild()
{
    lvs_var_log=/home/lvs/log/var_log
    if [ ! -d $lvs_var_log ]
    then
	mkdir -p $lvs_var_log
	/bin/cp -rf /var/log/* $lvs_var_log
	/bin/rm -rf /var/log
	ln -s $lvs_var_log /var/log
    else
	if [ ! -L /var/log ]
	then
	    /bin/cp -rf /var/log/* $lvs_var_log
	    ln -s $lvs_var_log /var/log 
	fi
    fi    
}

function dns_config()
{
    idc=$(echo "$hostname" | awk -F "." '{print $3}')
    for entry in $dns_table
    do
	if [[ $entry =~ "^$idc" ]]
	then
	    dns_list=$(echo "$entry" | awk -F ":" '{print $2}' | sed 's/|/ /g')
	    sed -i 's/nameserver.*//g' /etc/resolv.conf
	    sed -i '/^$/d' /etc/resolv.conf
	    for dns in $dns_list
	    do
		echo -e "nameserver\t$dns" >> /etc/resolv.conf
	    done
	fi
    done
}

function disk_extend()
{
    lvextend -l +100%FREE /dev/mapper/VolGroup00-LogVol03
    resize2fs /dev/VolGroup00/LogVol03
}


function ifcfg_backup()
{
    [ ! -d /tmp/ifcfg_bak ] && { /bin/mkdir -p /tmp/ifcfg_bak; /bin/cp -rf $ifcfg_dir/ifcfg-eth* /tmp/ifcfg_bak; }
    echo "ifcfg_backup"
}

function get_netmask()
{
    [ "$1" == "" ] && return
    mask=$1
    ((bits=32-$mask)) 
    
    let "var=0xffffffff>>$bits<<$bits"
    let "a=$var>>24, b=($var&((1<<24)-1))>>16, c=($var&((1<<16)-1))>>8, d=($var&((1<<8)-1))"
    echo "$a.$b.$c.$d"
}

function net_config()
{
    if [ "$ixgbe_nic_in" == "" ] || [ "$ixgbe_nic_out" == "" ]
    then
	return
    fi
    
    ifcfg_backup
    ixgbe_in_mac=$(ip addr list $ixgbe_nic_in | grep "link/ether" | awk '{print $2}')
    ixgbe_out_mac=$(ip addr list $ixgbe_nic_out | grep "link/ether" | awk '{print $2}')
    mgt_out_mac=$(ip addr list $mgt_nic_out | grep "link/ether" | awk '{print $2}')
    mgt_in_mac=$(ip addr list $mgt_nic_in | grep "link/ether" | awk '{print $2}')
    
    echo $(get_netmask 22)

    echo -e "DEVICE=eth0\nHWADDR=$ixgbe_out_mac\nONBOOT=yes\nBOOTPROTO=none\nTYPE=Ethernet\nIPADDR=$ospfd_ip\nNETMASK=$(get_netmask $ospfd_mask)\nGATEWAY=$ospfd_gw" > $ifcfg_dir/ifcfg-eth0
    echo -e "DEVICE=eth1\nHWADDR=$ixgbe_in_mac\nONBOOT=yes\nBOOTPROTO=none\nTYPE=Ethernet\nIPADDR=$ixgbe_nic_in_ip\nNETMASK=$(get_netmask $ixgbe_nic_in_mask)" > $ifcfg_dir/ifcfg-eth1
    echo -e "DEVICE=eth2\nHWADDR=$mgt_in_mac\nONBOOT=no\nBOOTPROTO=none\nTYPE=Ethernet\nIPADDR=$mgt_nic_in_ip\nNETMASK=$(get_netmask $mgt_nic_in_mask)\n#GATEWAY=$mgt_nic_in_gw" > $ifcfg_dir/ifcfg-eth2
    echo -e "DEVICE=eth3\nHWADDR=$mgt_out_mac\nONBOOT=yes\nBOOTPROTO=none\nTYPE=Ethernet\nIPADDR=$mgt_nic_out_ip\nNETMASK=$(get_netmask $mgt_nic_out_mask)\n#GATEWAY=$mgt_nic_out_gw" > $ifcfg_dir/ifcfg-eth3

    i=4
    for nic in $other_nics
    do
	echo "dev: $nic"
	mac=$(ip addr list $nic | grep "link/ether" | awk '{print $2}')
	echo -e "DEVICE=eth$i\nHWADDR=$mac\nONBOOT=no\nBOOTPROTO=none\nTYPE=Ethernet" > $ifcfg_dir/ifcfg-eth$i
	((i++))
    done
    if [ "$sys_ver" == "6.2" ]
    then
	echo "alias eth0 ixgbe" > $modprobe_conf
	echo "alias eth1 ixgbe" >> $modprobe_conf
	echo "alias eth2 igb" >> $modprobe_conf
	echo "alias eth3 igb" >> $modprobe_conf
	echo "alias eth4 igb" >> $modprobe_conf
	echo "alias eth5 igb" >> $modprobe_conf
	echo "alias scsi_hostadapter megaraid_sas" >> $modprobe_conf
	echo "alias net-pf-10 off" >> $modprobe_conf
	echo "options ipv6 disable=1" >> $modprobe_conf
	echo "options ip_vs ip_vs_L3_through=1" >> $modprobe_conf
    else
	sed -i 's/^alias eth0.*/alias eth0 ixgbe/g' $modprobe_conf
	sed -i 's/^alias eth1.*/alias eth1 ixgbe/g' $modprobe_conf
	sed -i 's/^alias eth2.*/alias eth2 igb/g' $modprobe_conf
	sed -i 's/^alias eth3.*/alias eth3 igb/g' $modprobe_conf
	sed -i 's/^alias eth4.*/alias eth4 igb/g' $modprobe_conf
	sed -i 's/^alias eth5.*/alias eth5 igb/g' $modprobe_conf
    fi

    echo "/sbin/ip route add 10/8 via $ixgbe_nic_in_gw" >> /etc/rc.local

#    cat /etc/resolv.conf | grep "nameserver" | awk -v gw="$mgt_nic_out_gw" '{print "/sbin/ip route add " $2 "/32 via " gw}' >> /etc/rc.local
#    echo "/sbin/ip route add 218.30.117.19/32 via $mgt_nic_out_gw" >> /etc/rc.local
#    echo "/sbin/ip route add 58.68.225.126/32 via $mgt_nic_out_gw" >> /etc/rc.local
#    echo "/sbin/ip route add 220.181.157.126/32 via $mgt_nic_out_gw" >> /etc/rc.local
#    echo "/sbin/ip route add 220.181.126.113/32 via $mgt_nic_out_gw" >> /etc/rc.local
#    echo "/sbin/ip route add 220.181.126.24/32 via $mgt_nic_out_gw" >> /etc/rc.local
    echo "/sbin/ip route change default via $ospfd_gw dev eth0 src $mgt_nic_out_ip" >> /etc/rc.local
    
#   rmmod igb
#    rmmod ixgbe
    
#    sleep 2

#   modprobe igb
#    modprobe ixgbe

#   ifdown eth2
#    ifup eth3
#    ifdown eth4
#    ifdown eth5
}

function authority_config()
{
    [ ! -d $main_dir/.ssh ] && /bin/mkdir -p $main_dir/.ssh
    /bin/cp -f $base/id_rsa.pub $main_dir/.ssh/authorized_keys
    chmod 700 $main_dir/.ssh
    chmod 600 $main_dir/.ssh/authorized_keys
    chown $user:$user -R $main_dir/.ssh
    sed -i "s/$user ALL = (ALL) ALL/$user ALL = (ALL) NOPASSWD:ALL/g" /etc/sudoers 
}

function comm_config()
{
    res=$(grep "/etc/rc.d/lvs_rc.local" /etc/rc.local)
	if [ "$res" == "" ]
	then
		echo "/etc/rc.d/lvs_rc.local -m $lvs_mode -l $l3_through -s $syn_proxy" >> /etc/rc.local
	else
		sed -i "s/\/etc\/rc.d\/lvs_rc.local.*/\/etc\/rc.d\/lvs_rc.local -m $lvs_mode -l $l3_through -s $syn_proxy/g" /etc/rc.local
	fi
#    echo "*/1 * * * * root /home/lvs/monitor/control.py" > /etc/cron.d/lvsstat
    echo "/home/bvs-manager/bvs/alarm.pl start" >> /etc/rc.local
    echo "0 0 * * * root sync && echo 2 > /proc/sys/vm/drop_caches" >> /etc/cron.d/lvsstat
    echo "*/1 * * * * root /home/lvs/lvs_status.pl" >> /etc/cron.d/lvsstat
    echo "0 */2 * * * root /bin/rm -f /home/lvs/ipvsadm_info" >> /etc/cron.d/lvsstat
    ntp_server=$(cat /etc/ntp.conf | grep "^server" | awk '{print $2}' | head -n 1)
    echo "1 0 * * * root ntpdate -u $ntp_server && kill -HUP \`cat /var/run/checkers.pid\`" >> /etc/cron.d/lvsstat
    echo "0 */2 * * * root /usr/sbin/logrotate /usr/local/etc/logrotate/lvs_rotate.conf" >> /etc/cron.d/lvsstat 

    echo "ntpdate -u $ntp_server && kill -HUP \`cat /var/run/checkers.pid\`" >> /etc/rc.local
    sed -i 's/02 4 \* \* \* root run\-parts \/etc\/cron.daily/02 0 \* \* \* root run\-parts \/etc\/cron.daily/g' /etc/crontab 
#    sed -i "s/localhost.localdomain/$hostname $(echo "$hostname" | sed "s/\.qihoo.net//g") localhost.localdomain/g" /etc/hosts
#    sed -i "s/HOSTNAME=*/HOSTNAME=$host/g" /etc/sysconfig/network
    #echo "1420" > /proc/sys/net/ipv4/vs/syn_proxy_init_mss
    sed -i 's/-*\/var\/log\/messages/-\/var\/log\/messages/g' $syslog_conf
    mkdir -p /home/lvs/cache/logwatch
    sed -i 's/^TmpDir.*/TmpDir = \/home\/lvs\/cache\/logwatch/g' /usr/share/logwatch/default.conf/logwatch.conf
    kernel_install
#    hostname $hostname
#    ganglia_config
    var_log_rebuild
    disk_extend
# /etc/init.d/gmond restart
    mkdir -p $keepalived_dir
    chmod 777 -R $keepalived_dir
    cp $base/keepalived.conf $keepalived_dir
    chmod 777 $keepalived_dir/keepalived.conf
#    touch /usr/local/etc/zebra.conf
#    touch /usr/local/etc/ospfd.conf
    dns_config
    authority_config
    if [ "$sys_ver" == "6.2" ]
    then
	sed -i 's/^modprobe_conf=.*/modprobe_conf=\/etc\/modprobe.d\/modprobe.conf/g' /etc/rc.d/lvs_rc.local
    fi
}

function lvs_config()
{
    echo "do lvs config"
    sed -i 's/\/var\/log\/messages$/&\nkern.debug\t\t\t\t\t\t\-\/home\/lvs\/log\/natlog/g' $syslog_conf
}

function nat_config()
{
    echo "do nat config"
#echo "echo 0 > /proc/sys/net/ipv4/vs/big_nat_acl_level" >> /etc/rc.local
    sed -i 's/ip_vs_wrr/ip_vs_rr/g' /home/lvs/alarm/conf 
}

function cluster_config()
{
    echo "do cluster config"   
    net_config
    sed -i 's/\/var\/log\/messages$/&\nkern.debug\t\t\t\t\t\t\-\/home\/lvs\/log\/natlog/g' $syslog_conf
}

function lvs_install()
{
    install_comm
    case $lvs_mode in
        lvs_dr|LVS_DR|lvs_nat|LVS_NAT)
            install_lvs
            ;;
        nat|NAT)
            install_nat
            ;;
        lvs_cluster|LVS_CLUSTER)
            install_cluster
            ;;
        *)
            echo -e "Error:\tunknown lvs mode $lvs_mode, only support lvs_dr/lvs_nat/nat"
            usage
            ;;
    esac
}

function sysntem_config()
{
    comm_config
    case $lvs_mode in
        lvs_dr|LVS_DR|lvs_nat|LVS_NAT)
            lvs_config
            ;;
        nat|NAT)
            nat_config
            ;;
        lvs_cluster|LVS_CLUSTER)
            cluster_config
            ;;
        *)
            echo -e "Error:\tunknown lvs mode $lvs_mode, only support lvs_dr/lvs_nat/nat"
            usage
            ;;
	esac
}

lvs_init
lvs_install
sysntem_config
