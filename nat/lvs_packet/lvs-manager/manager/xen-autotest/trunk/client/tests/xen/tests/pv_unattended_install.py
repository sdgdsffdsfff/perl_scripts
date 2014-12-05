import logging, time, socket
from autotest_lib.client.common_lib import error
import xen_utils, xen_test_utils


def run_pv_unattended_install(test,params,env):
    """
    PV unattended install test:
    1) Start a PV guest with kernel and ramdisk, after which do OS install 
       via kickstart
    2) Wait for the guest to shutdown, and then start the guest again
    3) If we can remote_login to the guest, then the test end with GOOD
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    if xen_utils.wait_for(vm.is_dead,float(params.get("install_timeout",3000)), 300, 15):
        logging.info("VM OS install finished, start the OS again")
        vm.create()
        session = xen_test_utils.wait_for_login(vm)

        if session:
            logging.debug("OS installed successfully,can log into VM --> %s" % vm.get_name())
            session.close()
        else:
            logging.error("OS installed maybe failed,can not log into VM --> %s" % vm.get_name())
    else:
        raise error.TestFail("PV OS install failed")    

    
