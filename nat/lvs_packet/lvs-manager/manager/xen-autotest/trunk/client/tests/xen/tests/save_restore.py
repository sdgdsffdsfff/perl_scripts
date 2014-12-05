import logging, time, os
from autotest_lib.client.common_lib import error
import xen_subprocess, xen_test_utils, xen_utils


def run_save_restore(test, params, env):
    """
    save and restore test for Xen:
    1) Got a living vm and make sure it is responsiable
    2) Save the vm to a file
    3) Restore vm from the file if needed
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))
    session = xen_test_utils.wait_for_login(vm)
    # Make sure VM is responsiable
    if session.is_responsive():
        session.close()
    else:
        logging.warn("session of %s is not responsive" % vm.get_name())
    
    save_path = "/tmp/%s.save" % vm.get_name() 
    
    try:
        save_vm(vm, save_path)

        if params.get("need_restore") == "yes":
            restore_vm(vm, save_path)
            session = xen_test_utils.wait_for_login(vm)
            if session.is_responsive():
                session.close()
            else:
                raise error.TestFail("VM become unreponsive after restore")
    
    finally:
        if os.path.exists(save_path):
            os.remove(save_path)        
    
    
def save_vm(vm, save_path):    
    xm_cmd = "xm save "
    vm_name = vm.get_name()

    xm_cmd = xm_cmd + vm_name + " %s" % save_path

    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug, \
                                           "(xm save) ", timeout=500)

    if status is None:
        # timeout
        raise error.TestFail("xm save failed for timeout")
    elif status != 0:
        raise error.TestFail("xm save failed for reason:%s" % output)
    else:
        logging.info("xm save succeed")


def restore_vm(vm, save_path):
    xm_cmd = "xm restore "

    xm_cmd = xm_cmd + " %s" % save_path

    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug, \
                                           "(xm restore) ", timeout=500)
    if status is None:
       # timeout
       raise error.TestFail("xm restore failed for timeout")
    elif status != 0:
       raise error.TestFail("xm restore failed for reason:%s" % output)
    else:
       logging.info("xm resotre finished") 

       
        
