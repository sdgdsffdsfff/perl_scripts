import logging, re
from autotest_lib.client.common_lib import error
import xm

def run_xm_info(test, params, env):
    """
    Simple test for "xm info" command

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    logging.info("Testing xm info...")
    xm_info = xm.get_Info()
    logging.debug("Xm info is %s" % xm_info)

    # Check all numeric field
    for field in ["cores_per_socket", "threads_per_core", "cpu_mhz",
              "total_memory", "free_memory", "xen_major", "xen_minor",
              "xen_pagesize"]:
        value = xm_info[field]
        if not value.isdigit():
            raise error.TestFail("Numeric field %s not all-numbers: %s"
                                 % (field, val))

    # Check cc_compiler
    if not re.match("gcc version", xm_info["cc_compiler"]):
        raise error.TestFail("Bad cc_compiler field: %s"
                             % xm_info["cc_compiler"])

    # Check cc_compile_by
    if not re.match("[A-z0-9_]+", xm_info["cc_compile_by"]):
        raise error.TestFail("Bad cc_compile_by field: %s"
                             % xm_info["cc_compile_by"])
