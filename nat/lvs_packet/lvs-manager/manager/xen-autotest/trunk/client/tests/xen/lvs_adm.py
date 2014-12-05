#!/usr/bin/python

import sys, os, time, logging
import getopt
import commands
import xen_config

tool_dir = ""
lvs_config = ""

tool_dir_default = os.path.join(os.path.dirname(sys.argv[0]), "")
lvs_config_default = os.path.join(os.path.dirname(sys.argv[0]), "lvs_config.cfg")

def usage():
    print "======================================="
    print "lvs_adm.py usage: lvs_adm.py [option]"
    print "\t-c/--conf:\tlvs ops config"
    print "\t-t/--tool:\tlvs tool"
    print "\t-h:\t\tlvs_adm.py help"


def config_run(params, tool_path):
    # Report the parameters we've received and write them as keyvals
    # logging.debug("Test parameters:")
    keys = params.keys()
    keys.sort()
    param_str = ""
    for key in keys:
        #logging.debug("    %s = %s", key, params[key])
	param_str += "%s=%s " % (key, params[key])
    
    try:
        t_type = params.get("type")
	
	tool = tool_path + "/" + t_type
	cmd_str = tool + " " + param_str
#	module_path = os.path.join(subtest_dir, '%s' % t_type)
#	if not os.path.isfile(module_path):
#	    raise "Error: can not find %s" % t_type
	#print cmd_str
#	ret = os.system(cmd_str) 
#	if 0 != (ret >> 8): 
#	    print "lvs config error"  
#	    sys.exit(1);  
#	ret, info = commands.getstatusoutput(cmd_str)
	ret = os.system(cmd_str) 
#	print info
	if 0 != (ret >> 8):
		print "lvsadm_cmd:", t_type
		sys.exit(ret>>8)
	
    except Exception, e:
	logging.error("Test failed: %s", e)
	logging.debug("Postprocessing on error...")
	raise

def check_opt():
    global tool_dir
    global lvs_config

    if not lvs_config:
	lvs_config = lvs_config_default
    if not tool_dir:
	tool_dir = tool_dir_default
    #print "lvs_config:\t", lvs_config
    #print "tool_dir:\t", tool_dir

def parse_opt():
    global tool_dir
    global lvs_config
    opt_str = "c:d:m:t:h";
    long_opt_str = ["conf=""dest=", "tool=", "master=", "help"];
    try:
	opts, args = getopt.getopt(sys.argv[1:], opt_str, long_opt_str);
    except getopt.GetoptError:
	usage();
	sys.exit(1);

    for o, val in opts:
	if o in ("-c", "--conf"):
	    lvs_config = val
	if o in ("-t", "--tool"):
	    tool_dir = val
	if o in ("-h", "--help"):
	    usage()
	    sys.exit()

def main():
    global tool_dir
    global lvs_config
    status_dict = {}

    parse_opt()
    check_opt()

    config = xen_config.config(lvs_config)
    list = config.get_list()

    # ---------------
    # Run the lvs_adm
    # ---------------
    for dict in list:
	if dict.get("skip") == "yes":
	    continue
	depend_satisfied = True
	for dep in dict.get("depend"):
	    for test_name in status_dict.keys():
		if not dep in test_name:
		    continue
		if not status_dict[test_name]:
		    depend_satisfied = False
		    break
	if depend_satisfied:
	    test_iterations = int(dict.get("iterations", 1))
	    current_status = config_run(params = dict, tool_path = tool_dir)
	else:
	    current_status = False
	status_dict[dict.get("name")] = current_status

if __name__ == "__main__":
    main();
