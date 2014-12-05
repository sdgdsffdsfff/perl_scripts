import os, logging, time
from autotest_lib.client.common_lib import error
import xen_utils, xen_test_utils, parse_win_results


def run_autoit(test, params, env):
    """
    A wrapper for AutoIt scripts.

    1) Log into a guest.
    2) Run AutoIt script.
    3) Wait for script execution to complete.
    4) Pass/fail according to exit status of script.

    keys for autoit:
    autoit_binary:
    autoit_entry:
    scritp_params:
    result_file:
    result_parser:

    @param test: XEN test object.
    @param params: Dictionary with test parameters.
    @param env: Dictionary with the test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))
    session = xen_test_utils.wait_for_login(vm)

    try:
        logging.info("Starting script...")

        # Collect test parameters
        autoit_binary = params.get("autoit_binary")
        autoit_entry = params.get("autoit_entry")
        script_params = params.get("autoit_params", "")
        result_file = params.get("result_file")
        result_parser = params.get("result_parser")
        timeout = float(params.get("autoit_timeout", 600))

        # Download the script resource from a remote server, or
        # prepare the script using rss?
        if params.get("download") == "yes":
            download_cmd = params.get("download_cmd")
            rsc_server = params.get("rsc_server")
            dst_rsc_dir = params.get("dst_rsc_dir")

            # Change dir to dst_rsc_dir, and remove 'autoit' there, then
            # download the resource.
            rsc_cmd = "cd %s && (rmdir /s /q autoit || del /s /q autoit) && " \
                      "%s %s" % (dst_rsc_dir, download_cmd, rsc_server)

            if session.get_command_status(rsc_cmd, timeout=timeout) != 0:
                raise error.TestFail("Download test resource failed.")
            logging.info("Download resource finished.")
        else:
            logging.info("No need to git clone autoit.")

        #sleep 30s to let guest finish post-startup programs,
        #thus we will have a light load env to test
        time.sleep(30)

        #command to run the test
        command = "%s %s %s" % (autoit_binary, autoit_entry, script_params)

        logging.info("---------------- Script output ----------------")
        status = session.get_command_status(command,
                                            print_func=logging.info,
                                            timeout=timeout)
        logging.info("---------------- End of script output ----------------")

        if status is None:
            raise error.TestFail("Timeout expired before script execution "
                                 "completed (or something weird happened)")
        if status != 0:
            raise error.TestFail("Script execution failed")

        #run the parser sub rutine to parse the raw result
        if result_file != None:
            command = "type %s" %result_file
            output = session.get_command_output(command,print_func=logging.info,timeout=timeout)
            result = parse_win_results.parse_results(output,result_parser)
# Record keyval file for performance testing
            if result !=None:
                test.write_perf_keyval(result)
            else:
                logging.info("No keyval get for performance analysis!")

    finally:
        session.close()
