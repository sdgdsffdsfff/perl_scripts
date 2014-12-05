import logging, re
from autotest_lib.client.common_lib import error
import xm, xen_test_utils

def run_acpi_check(test, params, env):
    """
    Simple test to check whether guest behave as request.
    1) acpi = 1 (on) dmesg should contain "ACPI: RSDP".
    2) acpi = 0 (off) dmesg should contain "ACPI: Interpreter disabled.".

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))
    session =  xen_test_utils.wait_for_login(vm)
 
    logging.info("Testing acpi on/off...")
    acpi_switch = params.get("acpi", 1)
    acpi_check_on_cmd = params.get("acpi_check_on_cmd")
    acpi_check_off_cmd = params.get("acpi_check_off_cmd")
    if acpi_switch == "1":
        status = session.get_command_status(acpi_check_on_cmd, timeout=30)
        if status == None:
            raise error.TestFail("Timeout when checking the acpi info.")
        elif status != 0:
            raise error.TestFail("ACPI is on but the dmesg do not contain "
                                 "'ACPI: RSDP' information.")
    else:
        status =  session.get_command_status(acpi_check_off_cmd, timeout=30)
        if status == None:
            raise error.TestFail("Timeout when checking the acpi info.")
        elif status != 0:
            raise error.TestFail("ACPI is off but the dmesg do not contain"
                                 "'ACPI: Unable to locate RSDP'")
