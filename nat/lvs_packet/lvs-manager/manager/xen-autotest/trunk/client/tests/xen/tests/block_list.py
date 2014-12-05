import logging
from autotest_lib.client.common_lib import error
import xm, xen_test_utils, xen_utils

def run_block_list(test, params, env):
    """
    xm block-list domU
    1) Attach disks and cdrom at boot
    2) Verify every disk or cdrom exist in domainU
    3) Get blocks number xm_blocks from host
    4) Get blocks number blocks_domainU from domainU
    5) xm_blocks should equal to blocks_domainU
    6) Here block devices contains both disk and cdrom

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    # Get block devices from "xm block-list" in host
    blocks_xm = len(xm.get_blocks_info(vm.name))
    logging.debug("Got %s block devices from host" % blocks_xm)

    # Verify every block device exist in domainU, get a total number of them
    blocks_domainU = 0
    for image_name in xen_utils.get_sub_dict_names(params, "images"):
        image_params = xen_utils.get_sub_dict(params, image_name)
        if not image_params.get("image_dev"):
            raise error.TestError("image params: No image_dev")
        frontend_device = image_params.get("image_dev")
        if xen_test_utils.blocks_exist_domainU(vm, frontend_device):
            logging.info("Block device(/dev/%s) exist in domainU"
                         % frontend_device)
            blocks_domainU += 1

# Comment this section,for cdrom in PV is treated as general disk
#    if params.get("cdrom"):
#        if not params.get("dev_cdrom"):
#            raise error.TestError("cdrom params: No dev_cdrom")
#        frontend_device = image_params.get("image_dev")
#        if xen_test_utils.blocks_exist_domainU(vm, frontend_device):
#            logging.info("Block device(/dev/%s) exist in domainU"
#                         % frontend_device)
#            blocks_domainU += 1

    logging.debug("Block devices in block-list is %s, in domainU is %s"
                  % (blocks_xm, blocks_domainU))
    if blocks_xm != blocks_domainU:
        raise error.TestFail("Block devices(%s) in block-list differ from block"
                             " devices(%s) in domainU"
                             % (blocks_xm, blocks_domainU))

