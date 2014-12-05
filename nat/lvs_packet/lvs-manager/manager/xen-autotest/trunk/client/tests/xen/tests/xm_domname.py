import logging
import xm, xen_test_utils, xen_subprocess
from autotest_lib.client.common_lib import error

def run_xm_domname(test, params, env):
    """
    test xm domname.

    @param test: xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    domname = xm.get_dom_name(vm.get_id())

    vmname = vm.name

    if domname != vmname:
        raise error.TestFail("xm domname failed: %s <> %s" % (domname,vmname))
