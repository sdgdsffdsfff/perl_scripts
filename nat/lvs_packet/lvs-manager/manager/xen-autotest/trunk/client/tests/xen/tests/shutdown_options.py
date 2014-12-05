import logging
import time
import xm, xen_test_utils, xen_subprocess
from autotest_lib.client.common_lib import error

def run_shutdown_options(test, params, env):
    """
    test shutdown options.

    @param test: xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    vmid = vm.get_id()

    session = xen_test_utils.wait_for_login(vm)

    option = params.get('option')
    if option == 'on_poweroff':
        # shutdown the guest using xm
        cmd = "xm shutdown %s" % vm.name
        status, output = xen_subprocess.run_fg(cmd, logging.debug)

    elif option == 'on_reboot':
        # reboot the guest
        vm.reboot()

    elif option == 'on_crash':
        # trigger crash event in the guest
        crash_trigger_cmd = params.get("crash_trigger_cmd")
        session.sendline(crash_trigger_cmd)

    # wait for a while to allow the domain to be proceeded
    time.sleep(30)

    # on_poweroff is used as state, could also be on_reboot, on_crash
    state = params.get('on_poweroff')
    if state == 'destroy':
        # check that the domain is destroyed
        if xm.is_DomainRunning(vm.name):
            raise error.TestFail("destroy domain %s failed, "
            "domain is still running" % vm.name)

    elif state == 'restart':
        # check that the domain is restarted by checking the running status and id
        if not xm.is_DomainRunning(vm.name):
            raise error.TestFail("restart domain %s failed, "
            "domain is not running" % vm.name)

        # wait for the domain to grow up
        session = xen_test_utils.wait_for_login(vm)

        domid = xm.get_dom_id(vm.name)
        if domid == vmid:
            raise error.TestFail("restart domain %s failed, "
            "the domain id should have been changed after restart" % vm.name)

    elif state == 'preserve':
        # still checked by the running status and id
        if not xm.is_DomainRunning(vm.name):
            raise error.TestFail("preserve domain %s failed, domain is not running"
            % vm.name)

        domid = xm.get_dom_id(vm.name)
        if domid != vmid:
            raise error.TestFail("preserve domain %s failed, "
            "the domain id has changed" % vm.name)

    elif state == 'rename-restart':
        # first, the domain should be restarted
        if not xm.is_DomainRunning(vm.name):
            raise error.TestFail("restart domain %s failed, "
            "domain is not running" % vm.name)

        # wait for the domain to grow up
        session = xen_test_utils.wait_for_login(vm)

        domid = xm.get_dom_id(vm.name)
        if domid == vmid:
            raise error.TestFail("restart domain %s failed, "
            "the domain id should have been changed after restart" % vm.name)

        # second, the original domain should be renamed
        rename = vm.name + '-1'
        if not xm.is_DomainRunning(rename):
            raise error.TestFail("rename domain %s failed, "
            "domain is not running" % vm.name)

        # clean up the renamed domain.
        # it can hold too much resource.
        xm.destroy_DomU(rename)
