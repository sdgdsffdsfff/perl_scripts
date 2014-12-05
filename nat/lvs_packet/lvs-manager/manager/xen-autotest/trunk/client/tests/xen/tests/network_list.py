import logging
from autotest_lib.client.common_lib import error
import xm, xen_test_utils

def run_network_list(test, params, env):
    """
    xm network-list domU
    1) Get vifs from host
    2) Get eths from domainU
    3) Number of vifs should equal to eths

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    # Get vifs from "xm network-list" in host
    vifs_xm = len(xm.get_NetworkInfo(vm.name))
    logging.debug("Got %s vifs from host" % vifs_xm)

    eths_domainU = xen_test_utils.get_domainU_eths(vm)

    if vifs_xm != eths_domainU:
        raise error.TestFail("Vifs(%s) in network-list differ from eths(%s)"
                             " in guest" % (vifs_xm, eths_domainU))

