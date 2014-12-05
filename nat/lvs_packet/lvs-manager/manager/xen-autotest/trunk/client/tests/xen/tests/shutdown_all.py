import logging
import xen_subprocess
from autotest_lib.client.common_lib import error

def run_shutdown_all(test, params, env):
    """
    Shut down all living vms in host
    Use -a and -w opts
    -a means all
    -w means wait

    @param test: xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    xm_cmd = "xm shutdown -aw"

    logging.info("Begin to shutdown all vms running in host...")
    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,
                                           "(xm shutdown) ", timeout=240)
    if status is None:
        raise error.TestFail("Shutdown all VMs, run command: %s timeout expires"
                             % xm_cmd)
    elif status != 0:
        raise error.TestFail("Shutdown all VMs, run command: %s failed" % xm_cmd)
