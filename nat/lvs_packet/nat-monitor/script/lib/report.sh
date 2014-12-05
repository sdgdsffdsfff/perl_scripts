#!/bin/sh

gsms="hadoop_dxt_logsget"
gemail="hadoop_dxt_logsget_emailonly"

function  doAlarm()
{
	hostname=`hostname`
        subject="["$hostname"] "$1
        content="["$hostname"] "$2
	dosms=$3
        ie="utf8"
        alarmCenter="http://alarms.ops.qihoo.net:8360/intfs/alarm_intf"
        nowTime=`date +%Y%m%d%T`

	if [[ ! -z "$dosms" ]] && [[ 1 -eq $dosms ]];then
            curl -d "ie=$ie" -d "group_name=$gsms" -d "subject=$subject" -d "content=$content" $alarmCenter -s 
        else
	    curl -d "ie=$ie" -d "group_name=$gemail" -d "subject=$subject" -d "content=$content" $alarmCenter -s   
	fi
} 
