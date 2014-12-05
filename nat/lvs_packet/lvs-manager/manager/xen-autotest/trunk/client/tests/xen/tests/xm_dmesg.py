import logging, random
from autotest_lib.client.common_lib import error
import xm

def run_xm_dmesg(test, params, env):
    """
    Simple test for "xm dmesg" command

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    logging.info("Testing xm dmesg...")
    xm_dmesg = xm.get_Dmesg()

    with_c = random.randint(0, 1)

    if with_c:
        xm_dmesg = xm.get_Dmesg("-c")
        if xm_dmesg:
            raise error.TestFail("Clear xen dmesg info with -c failed.")
    else:
        xm_dmesg = xm.get_Dmesg("--clear")
        if xm_dmesg:
            raise error.TestFail("Clear xen dmesg info with --clear failed.")


