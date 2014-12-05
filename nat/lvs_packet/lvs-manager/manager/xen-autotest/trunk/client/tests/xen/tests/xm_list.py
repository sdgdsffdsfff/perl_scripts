import logging
import xm, xen_test_utils

def run_xm_list(test, params, env):
    """
    Test for "xm list" command with all good and bad options
    For example:
    xm list 
    xm list domain(name/id)
    xm list --label
    xm list --long/-l
    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    logging.info("Testing xm list...")
    xm.get_DomInfo()

    xm.get_DomInfo(vm.name)

    xm.get_DomInfo(vm.get_id())

    xm.get_DomInfo("abcd")

    xm.get_DomInfo("6666")

    xm.get_DomInfo(opts="--label")

    xm.get_DomInfo(opts="-l")

    xm.get_DomInfo(vm.name, "--long")

    xm.get_DomInfo(vm.name, "-x")

    

