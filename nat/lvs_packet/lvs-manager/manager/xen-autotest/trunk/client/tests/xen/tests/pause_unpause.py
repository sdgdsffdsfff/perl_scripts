import logging, random
from autotest_lib.client.common_lib import error
import xen_test_utils, xen_subprocess, xm, xen_utils

def run_pause_unpause(test, params, env):
    """
    VM pause test:
    1)Get a living vm
    2)Get a session of the vm,then close it
    3)Pause the vm
    4)Verify it paused by vm still exists
                          vm's State contains "p"
                          failure to get session
    5)Unpause the vm
    6)Verify it unpaused by vm still exists
                            vm's State do not contains "p"
                            Success to get session
    7)Random pause and unpause vm for 10 times

    @param test: xen test object.
    @param params: Dictionary with the test parameters.
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    session = xen_test_utils.wait_for_login(vm)
    if session.is_responsive():
        session.close()
    else:
        raise error.TestNAError("Need a responsive vm")

    try:
        # Pause VM
        logging.info("Try to pause VM: %s" % vm.name)
        pause_domain(vm.name)

        if not xm.is_DomainRunning(vm.name):
            raise error.TestFail("Pause VM: %s failed, vm is disappeared"
                                 % vm.name)

        if not get_domain_state(vm, 2) == "p":
            raise error.TestFail("Pause VM: %s failed, vm's State does not "
                                 "contain \"p\"" % vm.name)

        session = xen_utils.wait_for(lambda: vm.remote_login(), 10)
        if session:
            session.close()
            raise error.TestFail("Pause VM: %s failed, still can connect to vm"
                             % vm.name)
    
        # Unpause VM
        if params.get("need_test_unpause") != "yes":
            return
        else:
            logging.info("Unpause VM: %s" % vm.name)
            unpause_domain(vm.name)    
        
        if not xm.is_DomainRunning(vm.name):
            raise error.TestFail("Unpause VM: %s failed, vm is disappeared" 
                             % vm.name)
    
        if get_domain_state(vm, 2) == "p":
            raise error.TestFail("Unpause VM: %s failed, vm's State still "
                                 "contains \"p\"" % vm.name)

        session = xen_utils.wait_for(lambda: vm.remote_login(), 10)
        if session:
            session.close() 
        else:
            raise error.TestFail("Unpause VM: %s failed, can not connect to vm"
                                 % vm.name)

        # Pause and unpause multiple
        for i in range(10):
            pauseit = random.randint(0,1)
            if pauseit:
                pause_domain(vm.name)
            else:
                unpause_domain(vm.name)
    finally:
        unpause_domain(vm.name)
        

def get_domain_state(vm, index):
    """
    State in "xm list": rbpsc-
    if paused, State is: --p---
    """
    doms_info = xm.get_DomInfo(vm.name)
    if doms_info.has_key(vm.name)and doms_info[vm.name].has_key("State"):
        full_state = doms_info[vm.name].get("State")
        if full_state:
            return full_state[index]


def pause_domain(domain):
    xm_cmd = "xm pause " + domain

    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,
                                           "(xm pause) ", timeout=60) 
    if status is None:
        raise error.TestFail("Pause VM, run command: %s timeout expires"
                             % xm_cmd)
    elif status != 0:
        raise error.TestFail("Pause VM, run command: %s failed" % xm_cmd)


def unpause_domain(domain):
    xm_cmd = "xm unpause " + domain

    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,
                                           "(xm unpause) ", timeout=60)

    if status is None:
        raise error.TestFail("Unpause VM, run command: %s timeout expires"
                             % xm_cmd)
    elif status != 0:
        raise error.TestFail("Unpause VM, run command: %s failed" % xm_cmd)
