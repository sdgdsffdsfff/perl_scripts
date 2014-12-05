#!/bin/bash

BVS_DIR="/home/bvs-manager/bvs"
MANAGER_SCRIPT_DIR="/home/bvs-manager/manager"
MANAGER_LOG_PATH="/home/bvs-manager/log"
MANAGER_CONF_DIR="/home/bvs-manager/conf"
MANAGER_CONF_BAK_DIR="/home/bvs-manager/conf_bak"

usage()
{
	echo "Usage:"
	echo " $0 bvs"
	echo " $0 manager"
	exit 1;
}

ok_or_err_exit()
{
	if [ $1 != 0 ]
	then
		echo "$1 Error"
		exit $2
	else
		echo "OK"
	fi
}

install_manager()
{
	echo -n "mkdir $MANAGER_SCRIPT_DIR..."
	if [ ! -d $MANAGER_SCRIPT_DIR ]
	then 
		mkdir -p $MANAGER_SCRIPT_DIR
		ok_or_err_exit $? 1
	else
		echo ;
	fi
	echo "touch $MANAGER_LOG_PATH..."
	touch $MANAGER_LOG_PATH
	echo "mkdir -p $MANAGER_CONF_DIR..."
	mkdir -p $MANAGER_CONF_DIR
	echo "mkdir -p $MANAGER_CONF_BAK_DIR..."
	mkdir -p $MANAGER_CONF_BAK_DIR
	echo -n "cp -rf ./manager/* $MANAGER_SCRIPT_DIR --reply=yes..."
	cp -rf ./manager/* $MANAGER_SCRIPT_DIR
	ok_or_err_exit $? 2
	echo -n "cp -rf ./manager/bvsadm /sbin/ --reply=yes..."
	cp -rf ./manager/bvsadm /sbin/
	ok_or_err_exit $? 3
}

install_bvs()
{	
	echo -n "mkdir $BVS_DIR..."
	if [ ! -d $BVS_DIR ]
	then
		mkdir -p $BVS_DIR
		ok_or_err_exit $? 1
	else
		echo ;
	fi
	echo -n "cp -rf ./bvs/* $BVS_DIR --reply=yes..."
	cp -rf ./bvs/* $BVS_DIR
	ok_or_err_exit $? 2
}

if [ -z $1 ];
then
	usage
fi

if [ "$1" == "bvs" ];
then
	install_bvs
elif [ "$1" == "manager" ];
then
	install_manager
else
	usage
fi

echo "Install $1 Finished."
