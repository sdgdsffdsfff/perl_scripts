import logging, re
from autotest_lib.client.common_lib import error
import xm

def run_xm_log(test, params, env):
    """
    Simple test for "xm log" command
    Print xend log

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    logging.info("Testing xm log...")
    xm_log = xm.get_xend_log()

    if re.match("^\[\d{4}", xm_log) is None:
        raise error.TestFail("Output is unnormal when get xend log with command:"
                             "%s\n output:%s" % (xm_cmd, output))


