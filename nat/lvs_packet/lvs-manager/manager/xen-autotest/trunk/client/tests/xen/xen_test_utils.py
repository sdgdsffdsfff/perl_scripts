"""
High-level test utility functions.

This module is meant to reduce code size by performing common test procedures.
Generally, code here should look like test code.
More specifically:
    - Functions in this module should raise exceptions if things go wrong
      (unlike functions in xen_utils.py and domain.py which report failure via
      their returned values).
    - Functions in this module may use logging.info(), in addition to
      logging.debug() and logging.error(), to log messages the user may be
      interested in (unlike xen_utils.py and domain.py which use
      logging.debug() for anything that isn't an error).
    - Functions in this module typically use functions and classes from
      lower-level modules (e.g. xen_utils.py, domain.py, xen_subprocess.py).
    - Functions in this module should not be used by lower-level modules.
    - Functions in this module should be used in the right context.
      For example, a function should not be used where it may display
      misleading or inaccurate info or debug messages.

@copyright: 2008-2009 Red Hat Inc.
"""

import time, os, logging, re, commands
from autotest_lib.client.common_lib import utils, error
import xen_utils, domain, xen_subprocess, xm


def get_living_vm(env, vm_name):
    """
    Get a VM object from the environment and make sure it's alive.

    @param env: Dictionary with test environment.
    @param vm_name: Name of the desired VM object.
    @return: A VM object.
    """
    vm = xen_utils.env_get_vm(env, vm_name)
    if not vm:
        raise error.TestError("VM '%s' not found in environment" % vm_name)
    if not vm.is_running():
        raise error.TestError("VM '%s' seems to be dead; test requires a "
                              "living VM" % vm_name)
    return vm


def wait_for_login(vm, nic_index=0, timeout=240, start=0, step=2):
    """
    Try logging into a VM repeatedly.  Stop on success or when timeout expires.

    @param vm: VM object.
    @param nic_index: Index of NIC to access in the VM.
    @param timeout: Time to wait before giving up.
    @return: A shell session object.
    """
    logging.info("Trying to log into guest '%s'..." % vm.name)
    session = xen_utils.wait_for(lambda: vm.remote_login(nic_index),
                                 timeout, start, step)
    if not session:
        raise error.TestFail("Could not log into guest '%s'" % vm.name)
    logging.info("Logged into guest '%s'" % vm.name)
    return session


def reboot(vm, session, method="shell", nic_index=0, timeout=240):
    """
    Reboot the VM and wait for it to come back up by trying to log in until
    timeout expires.

    @param vm: VM object.
    @param session: A shell session object.
    @param method: Reboot method.  Can be "shell" (send a shell reboot
            command).
    @param nic_index: Index of NIC to access in the VM, when logging in after
            rebooting.
    @param timeout: Time to wait before giving up (after rebooting).
    @return: A new shell session object.
    """
    if method == "shell":
        # Send a reboot command to the guest's shell
        session.sendline(vm.get_params().get("reboot_command"))
        logging.info("Reboot command sent; waiting for guest to go down...")
    elif method == "xm_reboot":
        # Use "xm reboot" command to reboot the VM
        vm.reboot()
        logging.info("Use \"xm reboot\" command to reboot the vm; waiting for "
                     "guest to go down...")
    else:
        logging.error("Unknown reboot method: %s" % method)

    # Wait for the session to become unresponsive and close it
    if not xen_utils.wait_for(lambda: not session.is_responsive(timeout=30),
                              120, 0, 1):
        raise error.TestFail("Guest refuses to go down")
    session.close()

    # Try logging into the guest until timeout expires
    logging.info("Guest is down; waiting for it to go up again...")
    session = xen_utils.wait_for(lambda: vm.remote_login(nic_index=nic_index),
                                 timeout, 0, 2)
    if not session:
        raise error.TestFail("Could not log into guest after reboot")
    logging.info("Guest is up again")
    return session


def migrate_local(vm, mig_timeout=3600):
    """
    Migrate VM locally
    """
    old_dom_id = xm.get_dom_id(vm.get_name())

    mig_cmd = "xm migrate -l %s localhost " % vm.get_name() 

    status, output = xen_subprocess.run_fg(mig_cmd,timeout=mig_timeout)
    if status is None:
        raise error.TestFail("Timeout elapsed while waiting for migration")
    if status != 0:
        raise error.TestFail("Migrate failed for %s" % output)

    new_dom_id = xm.get_dom_id(vm.get_name())

    if old_dom_id == new_dom_id:
        raise error.TestFail("xm migrate failed, domain id is still %s" % old_dom_id)    
    
    return vm

def migrate(vm, dst_host, mig_timeout=3600):
    """
    Migrate VM to Remote Machine
    """
    old_dom_id = xm.get_dom_id(vm.get_name())

    mig_cmd = "xm migrate -l %s %s " % (vm.get_name(), dst_host) 

    status, output = xen_subprocess.run_fg(mig_cmd,timeout=mig_timeout)
    if status is None:
        raise error.TestFail("Timeout elapsed while waiting for migration")
    if status != 0:
        raise error.TestFail("Migrate failed for %s" % output)

    # Here just return the instance of the original vm
    # althrough the vm is already migrated to remote
    return vm
     

def get_time(session, time_command, time_filter_re, time_format):
    """
    Return the host time and guest time.  If the guest time cannot be fetched
    a TestError exception is raised.

    Note that the shell session should be ready to receive commands
    (i.e. should "display" a command prompt and should be done with all
    previous commands).

    @param session: A shell session.
    @param time_command: Command to issue to get the current guest time.
    @param time_filter_re: Regex filter to apply on the output of
            time_command in order to get the current time.
    @param time_format: Format string to pass to time.strptime() with the
            result of the regex filter.
    @return: A tuple containing the host time and guest time.
    """
    host_time = time.time()
    session.sendline(time_command)
    (match, s) = session.read_up_to_prompt()
    if not match:
        raise error.TestError("Could not get guest time")
    s = re.findall(time_filter_re, s)[0]
    guest_time = time.mktime(time.strptime(s, time_format))
    return (host_time, guest_time)


def get_domainU_eths(vm):
    """
    Get eths from within DomainU
    """
    session = wait_for_login(vm)

    try:
        if not session.is_responsive():
            raise error.TestError("Get an unresponsive session")

        eths_chk_cmd = vm.params.get("eths_chk_cmd")

        status, output = session.get_command_status_output(eths_chk_cmd, 60)
        if status is None:
            raise error.TestError("Timeout when get eth number"
                                  "from within domainU:%s" % output)
        elif status != 0:
            raise error.TestError("Error when get eth number"
                                  "from within domainU:%s" % output)
        else:
            logging.debug("The number of eths in domainU is %s" % output)
            return int(output)

    finally:
        session.close()


def get_domainU_cpus(vm):
    """
    Get cpus from within DomainU
    """
    session = wait_for_login(vm)

    try:
        if not session.is_responsive():
            raise error.TestError("Get an unresponsive session")

        cpus_chk_cmd = vm.params.get("cpus_chk_cmd")

        status, output = session.get_command_status_output(cpus_chk_cmd, 60)
        if status is None:
            raise error.TestError("Timeout when get cpu number"
                                  "from within domainU:%s" % output)
        elif status != 0:
            raise error.TestError("Error when get cpu number"
                                  "from within domainU:%s" % output)
        else:
            logging.debug("The number of cpus in domainU is %s" % output)
            return int(output)

    finally:
        session.close()


def blocks_exist_domainU(vm, block_device):
    """
    Get block devices from within DomainU
    """
    session = wait_for_login(vm)

    try:
        if not session.is_responsive():
            raise error.TestError("Get an unresponsive session")

        cpus_chk_cmd = vm.params.get("blocks_chk_cmd") % block_device

        status, output = session.get_command_status_output(cpus_chk_cmd, 60)
        if status is None:
            raise error.TestError("Timeout when verify whether block device"
                                  "exist from within domainU:%s" % output)
        elif status != 0:
            logging.debug("Block device(/dev/%s) does not exist in domainU:%s"
                          % (block_device ,output))
            return False
        else:
            logging.debug("Block device %s exist in domainU,output:%s"
                          % (block_device, output))
            return True

    finally:
        session.close()

def get_domainU_uptime(vm):
    """
    Get uptime from within DomainU
    """
    session = wait_for_login(vm)

    try:
        if not session.is_responsive():
            raise error.TestError("Get an unresponsive session")

        uptime_chk_cmd = vm.params.get("uptime_chk_cmd")

        status, output = session.get_command_status_output(uptime_chk_cmd, 60)
        if status is None:
            raise error.TestError("Timeout when get uptime from within domainU:"
                                  "%s" % output)
        elif status != 0:
            error.TestError("Error when get uptime from within domainU:%s" % output)

        if vm.type == "hvm_win":
            strings = output.split(":")
            s = re.findall("(\d+)", strings[1])
            uptime = int(s[0])*24*3600 + int(s[1])*3600 + int(s[2])*60 + int(s[3])
        else:
            uptime = re.findall("(\d+)\.", output)[0]
        return int(uptime)

    finally:
        session.close()

def get_uptime_seconds(vm):
    """
    Get uptime time via xm uptime by seconds
    """

    uptime_list = xm.get_uptime(vm.name)[0]

    [day, hour, min, sec] = [0,0,0,0]    
    i = 1
    for word in uptime_list[1:]:
        if word == "days,":
            day = uptime_list[i-1]
        if re.match('\d+:\d+:\d+', word):
            [ hour, min, sec ] = word.split(':')  
        i = i + 1

    return ( 12 * 3600 * int(day) + 3600 * int(hour) + 60 * int(min) + int(sec) )
    
def differ_percent(base_value, check_value):
    """
    Get the percentange that check_value differs from base_value
    """
    delta = abs(check_value - base_value)
    return 100.0 * delta / base_value

