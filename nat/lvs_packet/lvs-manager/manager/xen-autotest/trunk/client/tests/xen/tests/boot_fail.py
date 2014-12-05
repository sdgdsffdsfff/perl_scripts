import xen_utils

def run_boot_fail(test, params, env):
    vm = xen_utils.env_get_vm(env, params.get('main_vm'))

    # acceptable 1: vm is not running
    if not vm.is_running():
        return

    try:
        xen_test_utils.wait_for_login(vm)
    except error.TestFail:
        # acceptable 2: vm is irresponsive
        return

    raise error.TestFail("The VM is unexpected alive.")
