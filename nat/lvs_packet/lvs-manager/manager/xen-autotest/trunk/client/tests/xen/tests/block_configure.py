import logging, time
from autotest_lib.client.common_lib import error
import xm, xen_test_utils, xen_utils, domain, xen_subprocess

def run_block_configure(test, params, env):
    """
    xm block-configure domU new_back_dev front_dev mode
    "xm block-configure" is only applicable for CDROM device,
    and only for change CD in CDROM.
    1) Attach CDROM at boot time(for both HVM and PV)
    2) Verify attach action successful
    3) Change CD in cdrom attached before by block-configure sub command
    4) Check the CD changed successful

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

#    # Verify attach success
#    if not xen_test_utils.blocks_exist_domainU(vm, params.get("dev_cdrom")):
#        raise error.TestError("Block device(backend:%s,frontend:/dev/%s) not"
#                              " exist" % (backend_device, params.get("dev_cdrom")))

    # Define helper function to configure block devices
    def configure_block(domain, backend_device, frontend_device, mode):
        xm_cmd = "xm block-configure %s %s %s %s" \
                 % (domain, backend_device, frontend_device, mode)
        status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,
                                           "(xm block-configure) ", timeout=60)
        if status is None:
            raise error.TestFail("Timeout when configure block device with command:"
                                 "%s\n output:%s" % (xm_cmd, output))
        elif status != 0:
            raise error.TestFail("Error when configure block device with command:"
                                 "%s\n output:%s" % (xm_cmd, output))


    def check_block_configure(dom_id, cdrom):
        cd_chk_cmd = vm.params.get("cd_chk_cmd") % (dom_id, cdrom)

        status, output = xen_subprocess.run_fg(cd_chk_cmd, logging.debug,
                                               "(xm xenstore-read) ", timeout=60)
        if status is None:
            raise error.TestFail("Timeout when check block configure result"
                                 " with command: %s\n output:%s "
                                 % (cd_chk_cmd, output))
        elif status != 0:
            raise error.TestFail("Block device configured error, output:%s"
                                 % output)
        

    # Configure cdrom with another_cdrom 
    if params.get("cdrom_another"):
        cdrom = params.get("cdrom_another")
        cdrom_path = xen_utils.get_path(test.bindir, cdrom)
        backend_device = "%s:%s" % (params.get("prefix_cdrom"), cdrom_path)

        if params.get("dev_cdrom"):
           frontend_device = "%s:cdrom" % params.get("dev_cdrom")
        else:
            raise error.TestError("cdrom params: No dev_cdrom")

        configure_block(vm.name, backend_device, frontend_device, "r")
        check_block_configure(vm.get_id(), params.get("cdrom_another"))

        logging.info("Block device(/dev/%s) configured with new backend(%s)" 
                     % (frontend_device, backend_device))
    else:
        raise TestError("There's no cdrom_another specified in configure file")



