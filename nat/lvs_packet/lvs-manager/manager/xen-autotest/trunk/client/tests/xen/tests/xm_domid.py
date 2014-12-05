import logging
import xm, xen_test_utils, xen_subprocess
from autotest_lib.client.common_lib import error

def run_xm_domid(test, params, env):
    """
    test xm domid.

    @param test: xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    domid = xm.get_dom_id(vm.name)

    vmid = vm.get_id();

    if domid != vmid:
        raise error.TestFail("xm domid failed: %d <> %d" % (domid,vmid))
