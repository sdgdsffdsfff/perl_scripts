import logging, time, os, random
from autotest_lib.client.common_lib import error
import xen_test_utils, xen_subprocess, xen_utils, xm


def run_dump_core_manual(test, params, env):
    """
    XEN dump core manually test:
    xm dump-core dom_name/dom_id
    xm dump_core dom_name core_file
    xm dump_core -C/--crash dom_name
    1) Call xm dump-core command to dump core
    2) Verify the core file generated correctly
    3) Finally,clear core file
    for "-C" opts only:
    4) Verify the vm was destroyed

    @param test: xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    core_file_default_path = params.get("core_file_default_path")
    time_stamp = time.strftime("%Y%m%d-%H%M")
    core_file_path = test.bindir 
    core_file = os.path.join(core_file_path, "%s_core_%s" % (vm.name, time_stamp))

    def delete_core_file(default_path=True, specified_path=None):
        if default_path:
            core_file_path = core_file_default_path
        else:
            core_file_path = specified_path
        core_file_del_cmd = params.get("core_file_del_cmd") % (core_file_path, vm.name)
        status, output = xen_subprocess.run_fg(core_file_del_cmd, logging.debug,\
                                               "(del core file) ", timeout=60)
        if status is None:
            raise error.TestError("Timeout when delete core file with command:"
                                 "%s\n output:%s" % (core_file_del_cmd, output))
        if status != 0:
            raise error.TestError("Error when delete core file with command:"
                                  "%s\n output:%s" % (core_file_del_cmd, output))

    try:
        def check_core_file(default_path=True, specified_path=None):
            if default_path:
                core_file_path = core_file_default_path
            else:
                core_file_path = specified_path
            core_file_chk_cmd = params.get("core_file_chk_cmd") % (core_file_path, vm.name)
            status, output = xen_subprocess.run_fg(core_file_chk_cmd, logging.debug,\
                                                   "(check core file) ", timeout=60)
            if status is None:
                raise error.TestError("Timeout when check core file with command:"
                                     "%s\n output:%s" % (core_file_chk_cmd, output))
            if status != 0:
                raise error.TestError("Error when check core file with command:"
                                      "%s\n output:%s" % (core_file_chk_cmd, output))

        delete_core_file()

        # test "xm dump-core dom_name"
        xm.dump_core(vm.name)
        check_core_file()
        delete_core_file()
        logging.info("Dump core with dom_name finished...")

        # test "xm dump-core dom_id"
        xm.dump_core(vm.get_id())
        check_core_file()
        delete_core_file()
        logging.info("Dump core with dom_id finished...")

        # test "xm dump_core dom_name core_file"
        xm.dump_core(vm.name, core_file)
        check_core_file(False, core_file_path)
        delete_core_file(False, core_file_path)
        logging.info("Dump core with core_file specified finished...")

        # test "xm dump_core -C/--crash dom_name"
        if random.randint(0,1):
            xm.dump_core(vm.name, "-C")
        else:
            xm.dump_core(vm.name, "--crash")
        check_core_file()
        delete_core_file()
        # check domain is destroyed
        tart_time = time.time()
        end_time = time.time() + 30
        while time.time() < end_time:
            if not xm.is_DomainRunning(vm.name):
                break
            time.sleep(2)       
        if xm.is_DomainRunning(vm.name):
            raise error.TestError("Domain not destroyed after dump core with"
                                  " \"-C/--crash\" opt")
        logging.info("Dump core with -C opt finished...")

    finally:
        delete_core_file()
        delete_core_file(False, core_file_path)
