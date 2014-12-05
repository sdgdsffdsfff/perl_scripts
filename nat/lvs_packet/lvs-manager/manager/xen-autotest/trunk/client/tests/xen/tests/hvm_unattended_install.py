import logging, time, socket
from autotest_lib.client.common_lib import error
import xen_utils, xen_test_utils


def run_hvm_unattended_install(test, params, env):
    """
    HVM unattended install test:
    1) Starts a VM with an appropriated setup to start an unattended OS install.
    2) Wait until the remote_login to the VM successfully.

    @param test: xen test object.
    @param params: Dictionary with the test parameters.
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    logging.info("Starting hvm unattended install watch process")
    
    # Remote login success when installation finish and reboot automatically
    session = xen_test_utils.wait_for_login(vm, timeout=float(params.get
                                           ("install_timeout", 3000)), step=60)

    if session:
        logging.debug("OS installed successfully,can log into VM --> %s" 
                      % vm.get_name())
        session.close()
    else:
        logging.error("OS installed maybe failed,can not log into VM --> %s" 
                      % vm.get_name())
