import os, logging, sys, shutil
from autotest_lib.client.common_lib import error
from autotest_lib.client.bin import utils
import xen_subprocess, xen_test_utils, xen_utils, scan_results


def run_check_smbios(test, params, env):
    """
    Check the smbios values

    @param test: Xen test object.
    @param params: Dictionary with test parameters.
    @param env: Dictionary with the test environment.
    """

    null_values = ['', 'Not Specified', 'None']
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))
    session = xen_test_utils.wait_for_login(vm,
                  timeout=int(params.get("login_timeout", 360)))

    out = session.get_command_output("dmidecode -q -t 1")
    type1_info = str2dict(out)
    if not (type1_info.has_key('Manufacturer')\
            and type1_info['Manufacturer'] not in null_values):
        raise error.TestFail("Munufacturer is not specified")
    if not (type1_info.has_key('Product Name')\
            and type1_info['Product Name'] not in null_values):
        raise error.TestFail("Product name is not specified")

    out = session.get_command_output("dmidecode -q -t 3")
    type3_info = str2dict(out)
    if not (type3_info.has_key('Manufacturer')\
            and type3_info['Manufacturer'] not in null_values):
        raise error.TestFail("Munufacturer is not specified")

    out = session.get_command_output("dmidecode -q -t 4")
    type4_info = str2dict(out)
    if not (type4_info.has_key('Manufacturer')\
            and type4_info['Manufacturer'] not in null_values):
        raise error.TestFail("CPU Munufacturer is not specified")

    out = session.get_command_output("dmidecode -q -t 16")
    type16_info = str2dict(out)
    if not (type16_info.has_key('Error Correction Type')\
            and type16_info['Error Correction Type'].find("Multi-bit ECC") >= 0):
        raise error.TestFail("Didn't find \"Multi-bit ECC\" in \"Error Correction Type\"")

def str2dict(str, keyval_sep=':', line_sep='\n'):
    """
    """
    dict = {}
    lines = str.split(line_sep)
    lines = map(lambda x:x.strip(), lines)
    for line in lines:
        if line.count(keyval_sep) == 1:
            (key, val) = line.split(keyval_sep)
            dict[key.strip()] = val.strip()
    return dict
