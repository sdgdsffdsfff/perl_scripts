import logging, re, commands
from autotest_lib.client.common_lib import error
import xm

def run_xm_help(test, params, env):
    """
    Test for "xm help" command with both good and bad options.
    xm help
    xm --help
    xm -h
    xm help --long
    xm -x
    xm

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    logging.info("Testing xm help...")

    # xm help
    xm_help_info = xm.get_HelpInfo("help")
    if xm_help_info:
        if xm_help_info.find("Usage:") == -1:
            raise error.TestFail("")

    # Check all subcommands
    skip_commands = ["top", "log", "serve"]
    sub_commands = []
    bad_commands = []
    MAX_ARGS = 10
    lines = xm_help_info.split("\n")
    for line in lines:
        match = re.match("^ ([a-z][^ ]+).*$", line)
        if match:
            sub_commands.append(match.group(1))

    logging.debug("checking all subcommands %s" % sub_commands)
    for c in sub_commands:
        if c in skip_commands:
            continue

        arglist = ""
        for i in range(0,MAX_ARGS+1):
            if i > 0:
                arglist += "%i " % i

            status, output = commands.getstatusoutput("xm %s %s" % (c, arglist))

            if output.find("Traceback") != -1:
                bad_commands.append(c + " " + arglist)
                logging.debug("Got Traceback: %s %s" % (c, arglist))

    if bad_commands:
        error.TestFail("Got a traceback on: %s" % str(bad_commands))
    
    # xm --help
    xm_help_info = xm.get_HelpInfo("--help")
    if xm_help_info:
        if xm_help_info.find("Usage:") == -1:
            raise error.TestFail("")

    # xm -h
    xm_help_info = xm.get_HelpInfo("-h")
    if xm_help_info:
        if xm_help_info.find("Usage:") == -1:
            raise error.TestFail("")

    # xm help --long
    xm_help_info = xm.get_HelpInfo("help --long")
    if xm_help_info:
        if xm_help_info.find("xm full list of subcommands:") == -1:
            raise error.TestFail("")

    # With bad options
    xm_help_info = xm.get_HelpInfo("-x")
    if xm_help_info:
        if xm_help_info.find("Error:") == -1:
            raise error.TestFail("")
        
    # With no options
    xm_help_info = xm.get_HelpInfo(" ")
    if xm_help_info:
        if xm_help_info.find("Usage:") == -1:
            raise error.TestFail("")
