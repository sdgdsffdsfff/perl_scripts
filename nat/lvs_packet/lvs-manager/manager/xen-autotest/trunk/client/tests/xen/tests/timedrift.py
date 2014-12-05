import logging, time, commands, re
from autotest_lib.client.common_lib import error
import xen_subprocess, xen_test_utils,xen_utils


def run_timedrift(test, params, env):
    """
    Time drift test (mainly for Windows guests):

    1) Log into a guest.
    2) Take a time reading from the guest and host.
    3) Run load on the guest and host.
    4) Take a second time reading.
    5) Stop the load and rest for a while.
    6) Take a third time reading.
    7) If the drift immediately after load is higher than a user-
    specified value (in %), fail.
    If the drift after the rest period is higher than a user-specified value,
    fail.

    @param test: Xen test object.
    @param params: Dictionary with test parameters.
    @param env: Dictionary with the test environment.
    """
    login_timeout=int(params.get("login_timeout", 360))
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))
    session = xen_test_utils.wait_for_login(vm, timeout=login_timeout)

    # Collect test parameters:
    # Command to run to get the current time
    time_command = params.get("time_command")
    # Filter which should match a string to be passed to time.strptime()
    time_filter_re = params.get("time_filter_re")
    # Time format for time.strptime()
    time_format = params.get("time_format")
    guest_load_command = params.get("guest_load_command")
    guest_load_stop_command = params.get("guest_load_stop_command")
    host_load_command = params.get("host_load_command")
    guest_load_instances = int(params.get("guest_load_instances", "1"))
    host_load_instances = int(params.get("host_load_instances", "0"))
    
    load_duration = float(params.get("load_duration", "30"))
    rest_duration = float(params.get("rest_duration", "10"))
    drift_threshold = float(params.get("drift_threshold", "200"))
    drift_threshold_after_rest = float(params.get("drift_threshold_after_rest",
                                                  "200"))

    guest_load_sessions = []
    host_load_sessions = []

    try:

        # Get time before load
        # (ht stands for host time, gt stands for guest time)
        (ht0, gt0) = xen_test_utils.get_time(session,
                                             time_command,
                                             time_filter_re,
                                             time_format)

        try:
            # Run some load on the guest
            logging.info("Starting load on guest...")
            for i in range(guest_load_instances):
                load_session = vm.remote_login(timeout=login_timeout)
                if not load_session:
                    raise error.TestFail("Could not log into guest")
                load_session.set_output_prefix("(guest load %d) " % i)
                load_session.set_output_func(logging.debug)
                load_session.sendline(guest_load_command)
                guest_load_sessions.append(load_session)

            # Run some load on the host
            logging.info("Starting load on host...")
            for i in range(host_load_instances):
                host_load_sessions.append(
                    xen_subprocess.run_bg(host_load_command,
                                          output_func=logging.debug,
                                          output_prefix="(host load %d) " % i,
                                          timeout=0.5))

            # Sleep for a while (during load)
            logging.info("Sleeping for %s seconds..." % load_duration)
            time.sleep(load_duration)

            # Get time delta after load
            (ht1, gt1) = xen_test_utils.get_time(session,
                                                 time_command,
                                                 time_filter_re,
                                                 time_format)

            # Report results
            host_delta = ht1 - ht0
            guest_delta = gt1 - gt0
            drift = 100.0 * (host_delta - guest_delta) / host_delta
            logging.info("Host duration: %.2f" % host_delta)
            logging.info("Guest duration: %.2f" % guest_delta)
            logging.info("Drift: %.2f%%" % drift)
            # Record drift in keyval file for performance testing
            test.write_perf_keyval({'timedrift':drift})

        finally:
            logging.info("Cleaning up...")
            # Stop the guest load
            if guest_load_stop_command:
                session.get_command_output(guest_load_stop_command)
            # Close all load shell sessions
            for load_session in guest_load_sessions:
                load_session.close()
            for load_session in host_load_sessions:
                load_session.close()

        # Sleep again (rest)
        logging.info("Sleeping for %s seconds..." % rest_duration)
        time.sleep(rest_duration)

        # Get time after rest
        (ht2, gt2) = xen_test_utils.get_time(session,
                                             time_command,
                                             time_filter_re,
                                             time_format)

    finally:
        session.close()

    # Report results
    host_delta_total = ht2 - ht0
    guest_delta_total = gt2 - gt0
    drift_total = 100.0 * (host_delta_total - guest_delta_total) / host_delta
    logging.info("Total host duration including rest: %.2f" % host_delta_total)
    logging.info("Total guest duration including rest: %.2f" % guest_delta_total)
    logging.info("Total drift after rest: %.2f%%" % drift_total)

    # Fail the test if necessary
    if abs(drift) > drift_threshold:
        raise error.TestFail("Time drift too large: %.2f%%" % drift)
    if abs(drift_total) > drift_threshold_after_rest:
        raise error.TestFail("Time drift too large after rest period: %.2f%%"
                             % drift_total)
