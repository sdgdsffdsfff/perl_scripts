#!/usr/bin/python
import os
import sys
import ConfigParser
import string
import time
import threading as thread

class Worker(thread.Thread):
	def __init__(self, cmd = None):
		thread.Thread.__init__(self)
		self.command = cmd
	
	def run(self):
		if self.command:
			os.system(self.command)

class DataStore(object):
	def __init__(self, path):
		self.fpath = path
		self.dmap = ConfigParser.ConfigParser()
		if not os.path.exists(self.fpath):
			f = file(self.fpath,"w+")
			f.write("[TIMEDATA]\n")
			f.close()

		self.dmap.read(self.fpath)
		if self.dmap.sections() == None:
			self.dmap.add_section('TIMEDATA')

	def get_last_tm(self, key):
		if key not in self.dmap.options('TIMEDATA'):
			return "0.0"
		else:
			return self.dmap.get("TIMEDATA",key)

	def set_this_tm(self, key, value):
		self.dmap.set("TIMEDATA", key, value)
	
	def dumptm(self):
		self.dmap.write(open(self.fpath,"w"))


if __name__ == '__main__':
        basedir = os.path.dirname(sys.argv[0])
        if basedir == None:
                basedir = './'
        elif not basedir.startswith('/'):
                basedir = './'+basedir
        else:
                pass
	
	cf = ConfigParser.ConfigParser()
   	cf.read(basedir + "/conf/control.conf")
	secs = cf.sections()
	secnt = len(secs)
    	if secnt <= 0:
		print "Control no configure, exiting ..."
        	sys.exit(0)
	
	logfile = file(basedir + "/control.log","a+")
	ds = DataStore(basedir + "/conf/last.time.dat")
	nowtime = time.time()

	workers = []
	for s in secs:
		filename = cf.get(s, "EXECFILE")
		interval = cf.get(s, "INTEVEL")
		argstr = cf.get(s, "ARGS")
		lasttm = string.atof(ds.get_last_tm(filename))
		if nowtime - lasttm >= string.atoi(interval):
			filepath = basedir + "/script/" + filename
			commandline = filepath + " " + argstr
			logfile.write("[EXEC] "+time.strftime("%Y-%m-%d %X",time.localtime(nowtime))+": "+commandline+"\n")
			#os.system(commandline)
			worker = Worker(commandline)
			workers.append(worker)
			worker.start()
			ds.set_this_tm(filename,"%.1f" % nowtime)
		else:
			pass
			
	ds.dumptm()
	logfile.close()
	for w in workers:
		w.join(10)
		workers.remove(w)
