import logging, re, time
from autotest_lib.client.common_lib import error
import xm, xen_test_utils, xen_subprocess, xen_utils

def run_xm_sysrq(test, params, env):
    """
    Simple test for "xm sysrq dom_name|dom_id letter" command
    Send a sysrq to a domain
    1)Got a living vm
    2)Enable sysrq key with in domain
    3)Send a sysrq(b) to a domain
    4)Verify domid changed after sending sysrq

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))
    session = xen_test_utils.wait_for_login(vm)

    logging.info("Testing xm sysrq...")
    enable_sysrq_cmd = params.get("enable_sysrq_cmd")
    domain_id = vm.get_id()
    try: 
        # Enable sysrq key first
        session.sendline(enable_sysrq_cmd)
        logging.info("Enable sysrq key with in domain")

        def do_sysrq(domain):
            xm_cmd = "xm sysrq %s b" % domain
            status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                                   "(xm sysrq) ", timeout=60)
            if status is None:
                raise error.TestFail("Timeout when send sysrq to domain with command:"
                                     "%s\n output:%s" % (xm_cmd, output))
            elif status != 0:
                raise error.TestFail("Error when send sysrq to domain with command:"
                                     "%s\n output:%s" % (xm_cmd, output))

        xen_utils.wait_for(lambda: xen_test_utils.get_uptime_seconds(vm) > 60, timeout=60)
        do_sysrq(vm.name)
        # Wait for a while before we check vm id
        time.sleep(5)
        domain_id_1 = vm.get_id()
        if domain_id == domain_id_1:
            raise error.TestFail("Domain doesn't reboot with sysrq(b) send to dom_name")
        else:
            logging.info("Domain rebooted by sending sysrq(b) to dom_name")
        
        # Get another session to login the rebooted machine
        session2 = xen_test_utils.wait_for_login(vm)
        try:
            session2.sendline(enable_sysrq_cmd)
            logging.info("Enable sysrq key within the rebooted domain")

            xen_utils.wait_for(func=lambda: xen_test_utils.get_uptime_seconds(vm) > 60, timeout=60, \
                            text="Wait for uptime is larger than 60 seconds")
            do_sysrq(domain_id_1)
            # Wait for a while before we check vm id
            time.sleep(5)
            domain_id_2 = vm.get_id()
            if domain_id_1 == domain_id_2:
                raise error.TestFail("Domain doesn't reboot with sysrq(b) send to dom_id")
            else:
                logging.info("Domain rebooted by sending sysrq(b) to dom_id")
        finally:
            session2.close()

    finally:
        session.close()

