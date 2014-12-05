import logging
from autotest_lib.client.common_lib import error
import xen_test_utils, xen_utils

def run_vcpu_boot_pin(test, params, env):
    """
    1.pin cpus at boot time
     1)set cpus = 0 when create vm
     2)verify whether we can get the vm session
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    vcpus_boot = int(params.get("vcpus", 1))

    session = xen_utils.wait_for(lambda: vm.remote_login(), 180)
    if not session:
        raise error.TestFail("Pin vm with %s vcpus to only 1 cpu at boot time "
                             "failed, can not connect to vm" % vcpus_boot)

