import logging, re, random, math, time
from autotest_lib.client.common_lib import error
import xen_test_utils, xm, xen_subprocess

def run_memset(test, params, env):
    """
    (1) Get a living vm for test
    (2) Set memory size via xm set serval times
    (3) Check the if the size of memory change as requested each time,
        from domain0 and from within domainU
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))


    times = random.randint(10,50)
         
    # Get current memory size
    origmem = vm.get_memsize()
    if origmem is None:
        raise error.TestFail("Couldn't get memory size from within DomainU")
    else:
        origmem = int(origmem)
               
    xenstore_maxmem = int(get_xenstore_maxmem(vm.get_name()))

    # Get Constrain of the test
    if params.get("maxmem") is None:
        # no maxmem set, then just skip this test
        logging.info("No maxmem set for VM, use value from xenstore...")
        maxmem = xenstore_maxmem
    else:
        maxmem = int(params.get("maxmem"))
        if maxmem != xenstore_maxmem:
            raise error.TestFail("maxmem in config file is %s, \
                  but in xenstore it is %s" % (maxmem, xenstore_maxmem))
        
    if maxmem < origmem:
        logging.warning("current memory size is larger an maxmem,\
                             skip this test...")
        return
    else:
        step_up = maxmem - origmem
        
    min_safemem = int(params.get("min_safemem","256"))
    if min_safemem > origmem:
        logging.warning("current memory size is less than\
                         min_safemem, skip this test...")
        return
    else:
        step_down = min_safemem - origmem

    currmem = origmem

    # Do the Test
    for i in range(0,times):
            
        amt = random.randint(step_down,step_up)

        # For HVM, it not supported to balloon up
        # beyond what it starts with(BZ #637646);
        # Currently, RHEL6 guests also exposes to
        # such problem(BZ #523122). Whether it is
        # fixed depending on upstream.
        if vm.get_domaintype() in ('hvm_linux',):
            target = min(origmem, origmem + amt)
        else:
            target = origmem + amt

        logging.info("[%i/%i] Current:%i Target: %i" % 
                       (i, times, currmem, target))
        
        cmd = "xm mem-set " + vm.get_name() + " %i" % target

        status, output = xen_subprocess.run_fg(cmd,logging.debug,
                                              "(xm mem-set) ", timeout=10)

        if status is None:
            raise error.TestFail("Time slapsed while setting memory \
                                                           size of domain")
        elif status != 0:
            raise error.TestFail("xm mem-set got error due to %s" % output) 

        # Sleep for a while to wait for memory size change to the target
        time.sleep(3)

        # Check 
        domainU_mem = \
             check_memory_size(vm, target, int(params.get("mem_threshold", 10)))

        logging.debug("Requested memory size is %i, \
                       and actual size chang to %i" % (target,int(domainU_mem)))
        currmem = domainU_mem

def get_xenstore_maxmem(dom):
    
    chk_mem_cmd = "xm li %s -l | grep maxmem" % dom
   
    # Get output via xm 
    (s, o) = xen_subprocess.run_fg(chk_mem_cmd)
    if s is None:
        raise error.TestFail("Time slapsed while do xm list")
    elif s != 0:
        raise error.TestFail("xm list got error due to %s" % o)

    # Parse the output 
    pattern = re.compile(r'\s*\(maxmem (\d+)\)') 

    maxmem = pattern.sub(r'\1',o)
    if re.match(r'\d+', maxmem) is None:
        raise error.TestFail("Cannot get maxmem from xenstore")
    else:
        return maxmem


def check_memory_size(vm, target, threshold):
    """
    Make sure memory size of vm doesn't differ far from target
    """
    # Check memory size from within DomainU    
    domainU_mem = vm.get_memsize()
    if domainU_mem is None:
        raise error.TestFail("Failed to get memory size")
    else:
        domainU_mem = int(domainU_mem)

    # Check memory size from Domain0
    domain0_mem = int(xm.get_DomMem(vm.get_name()))

    # Make sure they don't differ too far
    if xen_test_utils.differ_percent(domainU_mem, domain0_mem) > threshold:
        raise error.TestFail("Actual memory size is %i, but xm reported %i"
                              % (domainU_mem,domain0_mem))  
    elif xen_test_utils.differ_percent(domainU_mem, target) > threshold:
        raise error.TestFail("Requested memory size is %i, \
                          but actual size is %i" % (target,domainU_mem)) 
    return domainU_mem
