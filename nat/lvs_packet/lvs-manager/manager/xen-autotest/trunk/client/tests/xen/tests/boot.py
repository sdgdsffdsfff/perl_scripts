import logging, time
from autotest_lib.client.common_lib import error
import xen_test_utils 


def run_boot(test, params, env):
    """
    XEN reboot test:
    1) Log into a guest
    2) Send a reboot command 
    3) Wait until the guest is up again
    4) Log into the guest to verify it's up again

    @param test: xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))
    session = xen_test_utils.wait_for_login(vm)

    try:
        if not params.get("reboot_method"):
            return

        # Reboot the VM
        session = xen_test_utils.reboot(vm, session,
                                        params.get("reboot_method"))

    finally:
        session.close()
