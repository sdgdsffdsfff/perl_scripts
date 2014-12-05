import os, logging, time
from autotest_lib.client.common_lib import error
import xen_test_utils, xen_utils, xm


def run_check_cpuflags(test, params, env):
    """
    check the cpu flags within the DomU
    scp scripts/check_cpuflags.py to DomU, run it and check the output

    @param test: Xen test object.
    @param params: Dictionary with test parameters.
    @param env: Dictionary with the test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))
    session = xen_test_utils.wait_for_login(vm)

    remote_path = os.path.join(test.autodir, "tests/xen/scripts/check_cpuflags.py")
    local_path = "/tmp/check_cpuflags.py"
    session.sendline("rm -f %s" % local_path)
    vm.copy_files_to(remote_path, local_path)
    out = session.get_command_output("python %s" % local_path)
    if out.find("TEST cpuflags [PASS]") == 0:
        pass
    elif out.find("TEST cpuflags [FAIL]") == 0:
        raise error.TestFail(out)
    else:
        raise error.TestError(out)
