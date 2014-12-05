import logging
import xm, xen_test_utils, xen_subprocess
from autotest_lib.client.common_lib import error

def run_xm_destroy(test, params, env):
    """
    test xm destroy.

    @param test: xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    status = xm.destroy_DomU(vm.name)

    if status is None:
        raise error.TestFail("destroy command timeout expires")
    elif status != 0:
        raise error.TestFail("destroy command failed")

    if xm.is_DomainRunning(vm.name):
        raise error.TestFail("destroy domain %s failed, domain is still running" % vm.name)

    status, output = xen_subprocess.run_fg("ps -ef | grep qemu-dm | grep -v grep", logging.debug)

    if output.find('qemu-dm') >= 0:
        raise error.TestFail("qemu-dm is not killed after destroy the domain.")
