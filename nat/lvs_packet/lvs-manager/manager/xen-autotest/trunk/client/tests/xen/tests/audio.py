import logging, time, commands, re
from autotest_lib.client.common_lib import error
import xen_subprocess, xen_test_utils,xen_utils


def run_audio(test, params, env):
    """
    Test guest audio:
    1) Boot guest with -soundhw ***
    2) Log into guest
    3) Write a file which contains random content to device /dev/dsp,check
    succeed or not
    """

    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))
    session = xen_test_utils.wait_for_login(vm,
                  timeout=int(params.get("login_timeout", 360)))

    random_content_size = params.get("random_content_size")
    audio_test_cmd = params.get("audio_test_cmd") % random_content_size

    s, o = session.get_command_status_output(audio_test_cmd)
    if s != 0:
        raise error.TestFail("Test audio fail: %s" % o)
    logging.info("Guest audio test successfully finish")
