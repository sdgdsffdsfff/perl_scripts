import logging, math, re
from autotest_lib.client.common_lib import error
import xm, xen_test_utils, xen_subprocess

def run_xm_uptime(test, params, env):
    """
    Test for "xm uptime" command:
    xm uptime
    xm uptime domain(name/id)
    xm uptime -s domain(name/id)
    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    logging.info("Testing xm uptime...")
    uptime_domainU = xen_test_utils.get_domainU_uptime(vm)
    logging.info("Uptime from within domainU is %s" % uptime_domainU)


    uptime_xm = xen_test_utils.get_uptime_seconds(vm)

    logging.info("Uptime from host is %s" % uptime_xm)

    if math.fabs(uptime_domainU - uptime_xm) > params.get("uptime_inaccuracy", 20):
        raise error.TestFail("Uptime in domainU is %i, and in xm list is %i"
                              % (uptime_domainU, uptime_xm))
    else:
        logging.debug("Uptime in domainU is %i, and in xm list is %i"
                       % (uptime_domainU, uptime_xm))
