import logging, time
from autotest_lib.client.common_lib import error
import xm, xen_test_utils, xen_utils, xen_subprocess

def run_network_attach_detach(test, params, env):
    """
    xm network-attach domU
    xm network-detach domU device_id
    1) Attach network
    2) vifs from host or eths from domU should increase by 1
    3) Detach network
    4) Number of vifs and eths should decrease by 1
    5) Attach and Detach network multiple
    6) Detach all network interfaces not original

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    try:
        # Attach network
        vifs_xm = len(xm.get_NetworkInfo(vm.name))
        network_attach(vm.name)

        vifs_xm_attach = len(xm.get_NetworkInfo(vm.name))
        eths_domainU_attach = xen_test_utils.get_domainU_eths(vm)

        if not(vifs_xm_attach == vifs_xm + 1 and 
               eths_domainU_attach == vifs_xm + 1):
            raise error.TestFail("Network attach failed,vifs see from xm is %s,"
                                 " eths see from domainU is %s"
                                 % (vifs_xm_attach, eths_domainU_attach))

        if params.get("need_test_detach") != "yes":
            return 

        # Detach network:detach the last device in network-list
        device_id = xm.get_NetworkInfo(vm.name).pop()[0]
        network_detach(vm.name, device_id)

        time.sleep(1)
        vifs_xm_detach = len(xm.get_NetworkInfo(vm.name))
        eths_domainU_detach = xen_test_utils.get_domainU_eths(vm)

        if not(vifs_xm_detach == vifs_xm_attach - 1 and
           eths_domainU_detach == vifs_xm_attach - 1):
            raise error.TestFail("Network detach failed,vifs see from xm is %s,"
                                 " eths see from domainU is %s"
                                 % (vifs_xm_detach, eths_domainU_detach))

        # Attach and detach multiple
        for i in range(5):
            # Generate random MAC addr for attaching
            network_attach(vm.name, mac=xen_utils.random_mac())
            time.sleep(1)
            device_id = xm.get_NetworkInfo(vm.name).pop()[0]
            network_detach(vm.name, device_id)
        for i in range(5):
            # Try to attach nics without MAC specified as well
            network_attach(vm.name)
            time.sleep(1)
            device_id = xm.get_NetworkInfo(vm.name).pop()[0]
            network_detach(vm.name, device_id)

    finally:
        # Detach all network interfaces not original
        time.sleep(1)
        nic_boot = len(xen_utils.get_sub_dict_names(params, "nics"))
        vifs_xm_now = len(xm.get_NetworkInfo(vm.name))
        vifs_not_original = vifs_xm_now - nic_boot
        if vifs_not_original > 0:
            for info in xm.get_NetworkInfo(vm.name)[-vifs_not_original:]:
                device_id = info[0]
                network_detach(vm.name, device_id)


def network_attach(domain, type=None, mac=None, bridge=None, ip=None,
                   script=None, backend=None, vifname=None, rate=None,
                   model=None):

    xm_cmd = "xm network-attach %s" % domain
    if type:
        xm_cmd += " type=%s" % type
    if mac:
        xm_cmd += " mac=%s" % mac
    if bridge:
        xm_cmd += " bridge=%s" % bridge
    if ip:
        xm_cmd += " ip=%s" % ip
    if script:
        xm_cmd += " script=%s" % script
    if backend:
        xm_cmd += " backend=%s" % backend
    if vifname:
        xm_cmd += " vifname=%s" % vifname
    if rate:
        xm_cmd += " rate=%s" % rate
    if model:
        xm_cmd += " model=%s" % model

    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,
                                           "(xm network-attach) ", timeout=60)
    if status is None:
        raise error.TestFail("Timeout when attach network device with command:"
                             " %s\n output: %s" % (xm_cmd, output))
    elif status != 0:
        raise error.TestFail("Error when attach network device with command:"
                             " %s\n output: %s" % (xm_cmd, output))


def network_detach(domain, device_id):

    xm_cmd = "xm network-detach %s %s" %(domain, device_id)

    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,
                                           "(xm network-detach) ", timeout=60)
    if status is None:
        raise error.TestFail("Timeout when attach network device with command:"
                             " %s\n output: %s" % (xm_cmd, output))
    elif status != 0:
        raise error.TestFail("Error when detach network device with command:"
                             " %s\n output: %s" % (xm_cmd, output))


