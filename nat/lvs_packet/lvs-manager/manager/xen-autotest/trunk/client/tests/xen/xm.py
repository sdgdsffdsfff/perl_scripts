"""
These are miscellaneous utility functions that query xm
For functions with parametres, if name of the parametre 
is: 

'domain':
The parametre can be either a name or an id of a domain.
'name':
The parametre can only be a name of a domain.
'id':
The parametre can only be an id of a domain.

Otherwise, the function will trigger an error
"""

import commands, re, os, time, logging

from autotest_lib.client.common_lib import error
import xen_subprocess

    
def get_dom_id(domain):

    xm_cmd = "xm domid " + str(domain)
    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm domid) ", timeout=60)

    if status != 0 or "Traceback" in output:
        return -1
    if output == "None":
        return -1
    try:
        return int(output)
    except:
        raise error.TestError("xm domid failed:'%s'" % output)


def get_dom_name(domain):

    xm_cmd = "xm domname " + str(domain)
    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm domname) ", timeout=60)
    return output.strip()


def is_DomainRunning(domain):
    id = get_dom_id(domain);
    if id == -1:
        return False;
    else:
        return True;


def get_RunningDomains():
    
    xm_cmd = "xm list"
    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm list) ", timeout=60)
    if status != 0 or "Traceback" in output:
        raise error.TestError("xm list failed:'%s'" % output)
    
    lines = output.splitlines();
    domains = [];
    for l in lines[1:]:
        elms = l.split(" ", 1);
        domains.append(elms[0]);
    return domains;


def destroy_DomU(domain):

    xm_cmd = "xm destroy " + domain
    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm destroy) ", timeout=60)

    return status;


def destroyAllDomUs():

    attempt = 0
    trying = True

    while trying:
        try:
            attempt += 1
            domainList = get_RunningDomains()
            trying = False
        except Exception, e:
            if attempt >= 10:
               raise error.TestError("xm list not responding")
            time.sleep(1)
            logging.debug(e.trace)
            logging.info("Trying again to get a clean domain list...")

    for d in domainList:
        if not d == "Domain-0":
            destroy_DomU(d);


def get_DomMem(domain):

    xm_cmd = "xm list"
    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm list) ", timeout=60)
    if status is None:
        raise error.TestError("Timeout when get memory size via xm list")

    if status != 0:
        raise error.TestError("Got Error when get memory size via xm list \
                               due to: %s" % output)

    lines = re.split("\n", output)
    for line in lines:
        fields = re.sub(" +", " ", line).split()
        if domain.isdigit():
            if fields[1] == domain:
                return int(fields[2])
        else:
            if fields[0] == domain:
                return int(fields[2])
    
    logging.info("Did not find domain " + str(domain))       
    return None


def get_DomInfo(domain=None, opts=None):

    xm_cmd = "xm list"
    if domain:
        xm_cmd = xm_cmd + " %s" % domain
    if opts:
        xm_cmd = xm_cmd + " %s" % opts
    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm list) ", timeout=60)
    bad_domain_opts = False
    if status is None:
        raise error.TestFail("Timeout when get vms info with command:"
                             "%s\n output:%s" % (xm_cmd, output))
    elif status != 0:
        if domain:
            if is_DomainRunning(domain) and (not opts or opts in
                                             ["-l", "--long", "--label"]):
                raise error.TestFail("Error when get vms info with command:"
                                     "%s\n output:%s" % (xm_cmd, output))
            else:
                bad_domain_opts = True
        else:
            if not opts and opts in ["-l", "--long", "--label"]:
                raise error.TestFail("Error when get vms info with command:"
                                     "%s\n output:%s" % (xm_cmd, output))
            else:
                bad_domain_opts = True

    if bad_domain_opts:
        logging.debug("With bad domain or opts for xm list")
        return None

    if opts in ["-l", "--long"]:
        logging.debug("With -l or --long opts for xm list, return directly")
        return None

    lines = output.split("\n")

    # Get the key values from the first line headers
    cleanHeader = re.sub("\([^\)]+\)", "", lines[0])
    colHeaders = re.split(" +", cleanHeader)

    doms_info = {}

    for line in lines[1:]:
        domValues = {}
        values = re.split(" +", line)
        i = 1
        for value in values[1:]:
            domValues[colHeaders[i]] = value
            logging.debug("colHeaders[%s] is %s" %(i, value))
            i += 1
        doms_info[values[0]] = domValues

    return doms_info


def get_VcpuInfo(domain):

    xm_cmd = "xm vcpu-list %s" % domain
    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm vcpu-list) ", timeout=60)
    if status is None:
        raise error.TestFail("Timeout when get vcpus info with command:"
                             "%s\n output:%s" % (xm_cmd, output))
    elif status != 0:
        raise error.TestFail("Error when get vcpus info with command:"
                             "%s\n output:%s" % (xm_cmd, output))

    lines = output.split("\n")

    vcpus = {}

    for line in lines[1:]:
        if len(line) == 0:
            break
        cols = re.split(" +", line)
        if len(cols) == 8:
           # When the last column(CPU Affinity) is "any cpu" 
           sum = cols[6] + " " + cols[7]
           vcpus[int(cols[2])] = [cols[3], cols[4], sum]
        else:
           vcpus[int(cols[2])] = [cols[3], cols[4], cols[6]]

    # vcpus = {VCPUs:[CPU, State, CPU Affinity]}
    return vcpus


def get_Info():

    info = {}

    xm_cmd = "xm info" 
    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm info) ", timeout=60)
    if status is None:
        raise error.TestError("Timeout when get xen host info with command:"
                              "%s\n output:%s" % (xm_cmd, output))

    if status != 0:
        raise error.TestError("Error when get xen host info with command:"
                              "%s\n output:%s" % (xm_cmd, output))
    lines = output.split("\n")
    for line in lines:
        match = re.match("^([A-z_]+)[^:]*: (.*)$", line)
        if match:
            info[match.group(1)] = match.group(2)

    return info


def get_Dmesg(opts=None):

    xm_cmd = "xm dmesg"
    if opts:
        xm_cmd = xm_cmd + " %s" % opts
    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm dmesg) ", timeout=60)
    if status is None:
        raise error.TestFail("Timeout when get xen info with command:"
                             "%s\n output:%s" % (xm_cmd, output))

    if status != 0:
        raise error.TestFail("Error when get xen info with command:"
                             "%s\n output:%s" % (xm_cmd, output))

    return output

def get_HelpInfo(opts=None):

    if opts:
        xm_cmd = "xm" + " %s" % opts
    else:
        xm_cmd = "xm help"
    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm help) ", timeout=60)
    if status is None:
        raise error.TestError("Timeout when get xm help info with command:"
                              "%s\n output:%s" % (xm_cmd, output))

    if status != 0:
        if opts in ["help", "help --long", "-h", "--help", "--help --long",
                     "-h --long"]:
            raise error.TestError("Error when get xm help info with command:"
                                  "%s\n output:%s" % (xm_cmd, output))
        else:
            logging.debug("With bad opts for xm help")
            
    return output 


def get_NetworkInfo(domain):

    xm_cmd = "xm network-list %s" % domain
    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm network-list) ", timeout=60)

    if status is None:
        raise error.TestFail("Timeout when get network info with command:"
                             "%s\n output:%s" % (xm_cmd, output))
    elif status != 0:
        raise error.TestFail("Error when get network info with command:"
                             "%s\n output:%s" % (xm_cmd, output))

    lines = output.split("\n")

    network_ifs = []

    for line in lines[1:]:
        if len(line) == 0:
            break 
        cols = re.split(" +", line)
        network_ifs.append(cols)

    return network_ifs


def get_blocks_info(domain):

    xm_cmd = "xm block-list %s" % domain
    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm block-list) ", timeout=60)

    if status is None:
        raise error.TestFail("Timeout when get block devices info with command:"
                             "%s\n output:%s" % (xm_cmd, output))
    elif status != 0:
        raise error.TestFail("Error when get block devices info with command:"
                             "%s\n output:%s" % (xm_cmd, output))

    lines = output.split("\n")

    block_devices = []

    for line in lines[1:]:
        if len(line) == 0:
            break
        cols = re.split(" +", line)
        block_devices.append(cols)

    return block_devices


def get_uptime(domain=None, opt=None):

    xm_cmd = "xm uptime"
    if domain:
        if opt:
            xm_cmd = xm_cmd + " %s %s" % (opt, domain)
        else:
            xm_cmd = xm_cmd + " %s" % domain

    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm uptime) ", timeout=60)
    if status is None:
        raise error.TestFail("Timeout when get uptime of domain with command:"
                             "%s\n output:%s" % (xm_cmd, output))
    elif status != 0:
        raise error.TestFail("Error when get uptime of domain  with command:"
                             "%s\n output:%s" % (xm_cmd, output))

    if opt is None:
        lines = output.split("\n")
        xm_uptime = []

        for line in lines[1:]:
            if len(line) == 0:
                break
            cols = re.split(" +", line)
            xm_uptime.append(cols)

        return xm_uptime
    else:
        return output


def get_xend_log():

    xm_cmd = "xm log"
    status, output = xen_subprocess.run_fg(xm_cmd, "(xm log) ", timeout=60)
    if status is None:
        raise error.TestFail("Timeout when get xend log with command:"
                             "%s\n output:%s" % (xm_cmd, output))

    if status != 0:
        raise error.TestFail("Error when get xend log with command:"
                             "%s\n output:%s" % (xm_cmd, output))

    return output


def rename_dom(domain, new_domain_name):

    xm_cmd = "xm rename %s %s" % (domain, new_domain_name)
    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm rename) ", timeout=60)
    if status is None:
        raise error.TestFail("Timeout when rename a domain with command:"
                             "%s\n output:%s" % (xm_cmd, output))

    if status != 0:
        raise error.TestFail("Error when rename a domain with command:"
                             "%s\n output:%s" % (xm_cmd, output))


def dump_core(domain, opts=None, core_file_name=None):

    xm_cmd = "xm dump-core %s" % domain
    if opts:
        xm_cmd = xm_cmd + " " + opts
    if core_file_name:
        xm_cmd = xm_cmd + " " + core_file_name
    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm dump-core) ", timeout=120)
    if status is None:
        raise error.TestFail("Timeout when dump the core for a domain with"
                             " command:%s\n output:%s" % (xm_cmd, output))

    if status != 0:
        raise error.TestFail("Error when dump the core for a domain with"
                             " command:%s\n output:%s" % (xm_cmd, output))


def restart_xend():

    if os.access("/etc/init.d/xend", os.X_OK):
        status, output = xen_subprocess.run_fg("/etc/init.d/xend stop", \
                             logging.debug,"(stop xend) ", timeout=60)
        time.sleep(1)
        status, output = xen_subprocess.run_fg("/etc/init.d/xend start", \
                             logging.debug,"(stop start) ", timeout=60)

    else:
        status, output = xen_subprocess.run_fg("xend stop", \
                             logging.debug,"(stop xend) ", timeout=60)
        time.sleep(1)
        status, output = xen_subprocess.run_fg("xend start", \
                             logging.debug,"(stop start) ", timeout=60)

    if status is None:
        raise error.TestFail("Timeout when restart xend service,output:%s"
                             % output)

    if status != 0:
        raise error.TestFail("Error when restart xend service,output:%s"
                             % output)


def smp_ConcurrencyLevel():
    nr_cpus = int(get_Info()["nr_cpus"])

    return nr_cpus


