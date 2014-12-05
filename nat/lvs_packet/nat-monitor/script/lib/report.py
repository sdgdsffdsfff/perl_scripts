import os
import sys
import urllib
import socket

gsms="hadoop_dxt_logsget"
gemail="hadoop_dxt_logsget_emailonly"
###################################################
def doAlarm(title,content,dosms=False):
	hostname = "["+socket.gethostname()+"] "
	baseurl = "http://alarms.ops.qihoo.net:8360/intfs/alarm_intf"
	if dosms:
		params = urllib.urlencode({'group_name':gsms, 'subject': hostname+title, 'content': hostname+content})
		urllib.urlopen(baseurl,params).read()
	else:  
		params = urllib.urlencode({'group_name':gemail, 'subject': hostname+title, 'content': hostname+content})
		urllib.urlopen(baseurl,params).read()

if __name__ == '__main__':
	title="Wangfeng test"
	content="Wangfeng test"
	doAlarm(title,content,False)
