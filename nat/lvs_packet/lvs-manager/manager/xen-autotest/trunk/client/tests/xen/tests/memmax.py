import logging, re, random, math
from autotest_lib.client.common_lib import error
import xen_test_utils, xm, xen_subprocess

def run_memmax(test, params, env):
    """
    (1) Get a living vm for test
    (2) Get memmax from params
    (3) Get current memory size
    (4) Change memmax to a reasonable value
    (5) Try to enlarge memory size beyond memmax
    (6) Check if memmax take effect then
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))
    session = xen_test_utils.wait_for_login(vm)

    # Get maxmem 
    if params.get("maxmem") is None:
        # no maxmem set, then just skip this test
        logging.warning("No maxmem set for VM, \
                             skip this test...")
        return
    else:
        maxmem = int(params.get("maxmem"))

    # Get memory size
    origmem = int(params.get("memory"))
    if origmem is None:
        raise error.TestFail("Couldn't get memory size from params")
    else:
        origmem = int(origmem)
               
    if maxmem < origmem:
        raise error.TestFail("current memory size is larger an maxmem")
    
    # Generate a new reasonable value for maxmem
    new_maxmem = random.randint(origmem,maxmem)
    
    # Change maxmem to the new value
    maxmem_cmd = "xm mem-max " + vm.get_name() + " %i" % new_maxmem
    status, output = xen_subprocess.run_fg(maxmem_cmd,logging.debug,"(xm mem-max) ",\
                                                            timeout=10)
    if status is None:
        raise error.TestFail("Time eslapsed while setting maxmem")
    elif status != 0:
        raise error.TestFail("xm mem-max got error due to %s" % output)
    else:
        logging.info("Change maxmem to %i" % new_maxmem)

    # Try to enlarge memory size beyond new memmax
    logging.info("Trying to enlarge memory size to %i" % maxmem)
    memset_cmd = "xm mem-set " + vm.get_name() + " %i" % maxmem
    status, output = xen_subprocess.run_fg(memset_cmd,logging.debug,"(xm mem-set) ",\
                                                            timeout=10)
    if status is None:
        raise error.TestFail("Time eslapsed while setting memory size")
    elif status != 0:
        if not "Error: Memory size too large. Limit is" in output: 
            raise error.TestFail("xm mem-set got error due to %s" % output)

    # Check memory size again
    current_mem = vm.get_memsize()
    if current_mem is None:
        raise error.TestFail("Couldn't get memory size from within DomainU")
    else:
        current_mem = int(current_mem)
               
    if current_mem > new_maxmem:
        raise error.TestFail("current memory size is larger an maxmem")
    else:
        logging.info("Current maxmem is %i, and current memory size is %i" % \
                      (new_maxmem, current_mem))
    



       
