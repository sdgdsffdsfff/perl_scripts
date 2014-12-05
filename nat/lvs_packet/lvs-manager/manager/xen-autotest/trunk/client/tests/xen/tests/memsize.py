import logging, math
from autotest_lib.client.common_lib import error
import xen_test_utils, xm

def run_memsize(test, params, env):
    """
    (1) Get a living vm for test
    (2) Check memory size both from domain0 and from within domainU
    (3) Check if the two values are equivalent
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    # Check Memory Size from Domain0
    mem_xm = int(xm.get_DomMem(vm.get_name()))

    mem_domainU = vm.get_memsize()

    if mem_domainU is None:
        raise error.TestFail("Couldn't get memory size from within DomainU")

    mem_domainU = int(mem_domainU)
    
    if xen_test_utils.differ_percent(mem_xm, mem_domainU) > \
                                      params.get("mem_threshold", 10):
        raise error.TestFail("Mem diff too large: %.2f%%. Actual memory size is %i," 
                    "but in xm list it is %i" % ( mem_diff, mem_domainU, mem_xm))
    else: 
        logging.debug("Mem diff is: %.2f%%. Actual memory size is %i,"
   "and in xm list it is %i" % (abs(mem_xm - mem_domainU), mem_domainU, mem_xm))
