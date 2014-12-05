import logging, re
from autotest_lib.client.common_lib import error
import xm, xen_test_utils

def run_restart_xend(test, params, env):
    """
    Test when restart xend service, vm runs properly.
    1)Got a living vm
    2)Restart xend service
    3)Verify vm running properly

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))
    session = xen_test_utils.wait_for_login(vm)

    logging.info("Restarting xend service...")
    xm.restart_xend()

    try: 
        # xm rename dom_name new_domain_name1 
        if session.is_responsive():
            logging.info("Vm is still running properly")
        else:
            error.TestFail("Vm got error after restarting xend service")

    finally:
        session.close()

