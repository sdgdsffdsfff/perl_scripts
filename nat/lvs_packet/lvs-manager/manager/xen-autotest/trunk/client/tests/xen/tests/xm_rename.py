import logging, re
from autotest_lib.client.common_lib import error
import xm, xen_test_utils

def run_xm_rename(test, params, env):
    """
    Simple test for "xm rename" command
    Rename a domain
    1)Rename a domain by "xm rename dom_name new_name1"
    2)Verify current domain name is new_name1 and vm session is responsive
    3)Rename a domain by "xm rename dom_id new_name2"
    4)Verify current domain name is new_name2 and vm session is responsive

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))
    session = xen_test_utils.wait_for_login(vm)

    logging.info("Testing xm rename...")
    new_domain_name1 = params.get("new_domain_name1")
    new_domain_name2 = params.get("new_domain_name2")
    domain_id = vm.get_id()
    try: 
        # xm rename dom_name new_domain_name1 
        xm.rename_dom(vm.name, new_domain_name1)
        current_domain_name = xm.get_dom_name(domain_id)
        if current_domain_name == new_domain_name1 and session.is_responsive():
            logging.info("New domain name is %s" % new_domain_name1)
        else:
            error.TestFail("Error when rename domain name, current domain name is"
                           "%s, and the destination domain name is %s" 
                           % (current_domain_name, new_domain_name1))

        # xm rename dom_id new_domain_name2
        xm.rename_dom(domain_id, new_domain_name2)
        current_domain_name = xm.get_dom_name(domain_id)
        if current_domain_name == new_domain_name2 and session.is_responsive():
            logging.info("New domain name is %s" % new_domain_name2)
        else:
            error.TestFail("Error when rename domain name, current domain name is"
                           "%s, and the destination domain name is %s" 
                           % (current_domain_name, new_domain_name2))
    finally:
        xm.rename_dom(domain_id, vm.name)
        session.close()

