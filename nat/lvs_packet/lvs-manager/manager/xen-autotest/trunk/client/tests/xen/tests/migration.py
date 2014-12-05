import logging, re, random, math, time
from autotest_lib.client.common_lib import error
import xen_test_utils, xm, xen_subprocess


def run_migration(test, params, env):
    """
    (1) Get a living vm for test
    (2) Log into the guest and run a command
    (3) Start a background process within the guest
    (4) Do the migration
    (5) After migration, log into the guest again and check if 
        the background process is still running
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))
    session = xen_test_utils.wait_for_login(vm)
    
    mig_timeout = float(params.get("mig_timeout", "3600"))
    
    # Get the output of migration_test_command
    test_command = params.get("migration_test_command")
    if not test_command:
        raise error.TestError("No migration_test_command set for this test")
    reference_output = session.get_command_output(test_command)

    # Start some process in the background (and leave the session open)
    background_command = params.get("migration_bg_command", "")
    session.sendline(background_command)
    time.sleep(5)

    # Start another session with the guest and make sure the background
    # process is running
    session2 = xen_test_utils.wait_for_login(vm)

    try:
        check_command = params.get("migration_bg_check_command", "")
        if session2.get_command_status(check_command, timeout=30) != 0:
            raise error.TestError("Could not start background process '%s'" %
                                  background_command)
        session2.close()

        # Migrate the VM
        dest_vm = xen_test_utils.migrate_local(vm, mig_timeout)

        # Log into the guest again
        logging.info("Logging into guest after migration...")
        session2 = xen_test_utils.wait_for_login(dest_vm)
        if not session2:
            raise error.TestFail("Could not log into guest after migration")
        logging.info("Logged in after migration")

        # Make sure the background process is still running
        if session2.get_command_status(check_command, timeout=30) != 0:
            raise error.TestFail("Could not find running background process "
                                 "after migration: '%s'" % background_command)

        # Get the output of migration_test_command
        output = session2.get_command_output(test_command)

        # Compare output to reference output
        if output != reference_output:
            logging.info("Command output before migration differs from "
                         "command output after migration")
            logging.info("Command: %s" % test_command)
            logging.info("Output before:" +
                         xen_utils.format_str_for_message(reference_output))
            logging.info("Output after:" +
                         xen_utils.format_str_for_message(output))
            raise error.TestFail("Command '%s' produced different output "
                                 "before and after migration" % test_command)

    finally:
        # Kill the background process
        if session2 and session2.is_alive():
            session2.get_command_output(params.get("migration_bg_kill_command",
                                                   ""))

    session2.close()
    session.close()
