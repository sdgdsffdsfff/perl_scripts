import os, logging, time, fcntl, subprocess
from autotest_lib.client.common_lib import error
import xen_test_utils, xen_utils, domain


def run_pxeboot(test, params, env):
    """
    XEN pxeboot test:
    1) Boot from network
    2) snoop the tftp packet

    Note: We're booting vm here rather than in preprocess to capture the tftp
    packet.

    @param test: xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """

    ifname = 'xenbr0' # TODO: Check the xen bridge here
    logging.debug("snoop the tftp packet of interface %s" % ifname)
    tcpdump_filename = os.path.join('/tmp', "pxe_tcp_dump")
    dump = open(tcpdump_filename, "a")
    tcpdump = subprocess.Popen(("tcpdump","-l","-n","port","69","-i",ifname),stdout=subprocess.PIPE)
    fcntl.fcntl(tcpdump.stdout.fileno(),fcntl.F_SETFL,os.O_NONBLOCK)

    def pxe_succeed():
        try:
            line = tcpdump.stdout.readline().strip()
            while line:
                dump.write(line)
                if 'tftp' in line:
                    logging.info("found tftp packet in the traffic")
                    return True
                line = tcpdump.stdout.readline()
            logging.error("no tftp packet found")
            return False
        except IOError:
            logging.error("no tftp packet found")
            return False

    name = params['main_vm']
    vm = xen_utils.env_get_vm(env, name)
    if vm:
        logging.debug("VM object found in environment")
    else:
        logging.debug("VM object does not exist; creating it")
        vm = domain.XenDomain(name, params, test.bindir, env.get("address_cache"))
        xen_utils.env_register_vm(env, name, vm)

    if vm.is_running():
        vm.destroy(gracefully=False)

    if not vm.create(name, params, test.bindir, env):
        raise error.TestError("Could not start VM")

    try:
        status = xen_utils.wait_for(pxe_succeed, 120, 0, 5)
        if status != True:
            raise error.TestFail("Couldn't find tftp packet on interface %s" % ifname)
    finally:
        if vm.is_running():
            vm.destroy(gracefully=False)
        dump.close()
        xen_utils.safe_kill(tcpdump.pid, 9)
