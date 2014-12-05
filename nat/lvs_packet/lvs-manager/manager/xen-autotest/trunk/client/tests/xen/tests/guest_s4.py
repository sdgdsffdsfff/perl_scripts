import logging, time
from autotest_lib.client.common_lib import error
import xen_test_utils, xen_utils, xm


def run_guest_s4(test, params, env):
    """
    Suspend guest to disk, supports Linux OSes.
    1) Login the guest, start up a background process
    2) Make the guest suspend to disk
    3) Recreate the guest
    4) Check the background process still running

    @param test: Xen test object.
    @param params: Dictionary with test parameters.
    @param env: Dictionary with the test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))
    session = xen_test_utils.wait_for_login(vm)

    logging.info("Checking whether the guest OS supports suspend to disk (S4)...")
    session.sendline(params.get("check_s4_support_cmd"))

    # Start up a program (tcpdump for linux), as a flag.
    # If the program died after suspend, then fail this case.
    test_s4_cmd = params.get("test_s4_cmd")
    session.sendline(test_s4_cmd)
    time.sleep(5)

    # Get the second session to start S4
    session2 = xen_test_utils.wait_for_login(vm)

    # Make sure the background program is running as expected
    check_s4_cmd = params.get("check_s4_cmd")
    session2.sendline(check_s4_cmd)
    logging.info("Launched background command in guest: %s" % test_s4_cmd)

    # Suspend to disk
    logging.info("Starting suspend to disk now...")
    session2.sendline(params.get("set_s4_cmd"))

    # Make sure the VM goes down
    if not xen_utils.wait_for(lambda: not xm.is_DomainRunning(vm.name), 240):
        raise error.TestFail("VM refuses to go down. Suspend failed.")
    logging.info("VM suspended successfully. Sleeping for a while before "
                 "resuming it.")
    time.sleep(10)

    # Recreate vm
    logging.info("Resuming suspended VM...")
    if not vm.create():
        raise error.TestError("Failed to recreate VM after suspending to disk")

    # Log into the resumed VM
    session2 = xen_test_utils.wait_for_login(vm)
    if not session2:
        raise error.TestFail("Could not log into VM after resuming")

    # Check whether the test command is still alive
    logging.info("Checking if background command is still alive...")
    session2.sendline(check_s4_cmd)

    logging.info("VM resumed successfuly after suspend to disk")
    session2.sendline(params.get("kill_test_s4_cmd"))
    session.close()
    session2.close()
