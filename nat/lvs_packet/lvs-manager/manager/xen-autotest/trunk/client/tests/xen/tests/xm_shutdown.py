import logging
import xm, xen_test_utils, xen_subprocess, xen_utils
from autotest_lib.client.common_lib import error

def run_xm_shutdown(test, params, env):
    """
    Test xm shutdown with different options.
    -w/--wait    check dom not runnig
    -a/--all     check dom not running
    -R/--reboot  check dom_id changed & could login vm after reboot
    -H/--halt    check dom not running

    @param test: xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))
    # When several shutdown cases running together, make sure the vm is a really running vm
    session = xen_test_utils.wait_for_login(vm)
    dom_id_ori = vm.get_id()

    options = params.get("options")
    xm_shutdown_opt(vm.name, options)

    check = params.get("check")
    if check == "yes":
        is_down = xen_utils.wait_for(lambda: not xm.is_DomainRunning(vm.name), 240)
        if not is_down:  
            raise error.TestFail("shutdown domain %s failed, domain is still running" % vm.name)

    relogin = params.get("relogin")
    if relogin == "yes":
        # Check domain reboot firstly
        dom_id_changed = xen_utils.wait_for(lambda: dom_id_change(dom_id_ori, vm), 240)
        if not dom_id_changed:
            raise error.TestFail("Domain doesn't reboot with -R/--reboot option")
        else:
            logging.info("Domain rebooted with -R/--reboot option")

        session = xen_test_utils.wait_for_login(vm)
        if not session.is_responsive():
            raise error.TestFail("cannot login into %s after reboot" % vm.name)


def xm_shutdown_opt(dom, opt):
    if opt:
        xm_cmd = "xm shutdown %s %s" % (opt, dom)
    else:
        xm_cmd = "xm shutdown " + dom

    logging.info("running " + xm_cmd)
    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,
                                           "(xm shutdown) ", timeout=240)
    if status is None:
        raise error.TestFail("Shutdown command: %s timeout expires"
                             % xm_cmd)
    elif status != 0:
        raise error.TestFail("Shutdown command: %s failed" % xm_cmd)


def dom_id_change(dom_id_ori, vm):
    dom_id_new = vm.get_id()
    if dom_id_new == dom_id_ori:
        return False;
    else:
        return True;

