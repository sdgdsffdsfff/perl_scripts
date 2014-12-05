import logging, time
from autotest_lib.client.common_lib import error
import xen_test_utils, xen_subprocess, xen_utils, xm


def run_dump_core_auto(test, params, env):
    """
    XEN dump core automatically test:
    Need add:"(enable-dump yes)" to /etc/xen/xend-config.sxp file
    and restart xend service
    1) Log into a guest
    2) Trigger a crash in the domain
    3) Wait until dump core finished
    4) Verify the core file generated correctly
    5) Finally,clear core file

    @param test: xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))
    session = xen_test_utils.wait_for_login(vm)
    core_file_default_path = params.get("core_file_default_path")

    def delete_core_file():
        core_file_del_cmd = params.get("core_file_del_cmd") % (core_file_default_path, vm.name)
        status, output = xen_subprocess.run_fg(core_file_del_cmd, logging.debug,\
                                               "(del core file) ", timeout=60)
        if status is None:
            raise error.TestError("Timeout when delete core file with command:"
                                 "%s\n output:%s" % (core_file_del_cmd, output))
        if status != 0:
            raise error.TestError("Error when delete core file with command:"
                                  "%s\n output:%s" % (core_file_del_cmd, output))

    try:
        def check_core_file():
            core_file_chk_cmd = params.get("core_file_chk_cmd") % (core_file_default_path, vm.name)
            status, output = xen_subprocess.run_fg(core_file_chk_cmd, logging.debug,\
                                                   "(check core file) ", timeout=60)
            if status is None:
                raise error.TestError("Timeout when check core file with command:"
                                     "%s\n output:%s" % (core_file_chk_cmd, output))
            if status != 0:
                raise error.TestError("Error when check core file with command:"
                                      "%s\n output:%s" % (core_file_chk_cmd, output))

        delete_core_file()
        crash_trigger_cmd = params.get("crash_trigger_cmd")
        session.sendline(crash_trigger_cmd)
        logging.info("Trigger crash...")

        # Wait for dump finish
        domain_id = vm.get_id()
        start_time = time.time()
        end_time = time.time() + 60
        while time.time() < end_time:
            if domain_id != xm.get_dom_id(vm.name):
                break
            time.sleep(5)

        check_core_file()
        logging.info("Dump core finished...")
    finally:
        session.close()
        delete_core_file()
