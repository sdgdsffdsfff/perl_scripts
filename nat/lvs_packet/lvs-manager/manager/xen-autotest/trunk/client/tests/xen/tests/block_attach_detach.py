import logging, time
from autotest_lib.client.common_lib import error
import xm, xen_test_utils, xen_utils, domain, xen_subprocess

def run_block_attach_detach(test, params, env):
    """
    xm block-attach domU back_dev front_dev mode
    xm block-detach domU dev_id
    1) Attach all additional disks assigned in config file
    2) Verify every attach action successful
    3) Detach all disks attached before
    4) Verify every detach action successful

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    def attach_block(domain, backend_device, frontend_device, mode):
        xm_cmd = "xm block-attach %s %s %s %s" % (domain, backend_device, frontend_device, mode)
        status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,
                                           "(xm block-attach) ", timeout=60)
        if status is None:
            raise error.TestFail("Timeout when attach block device with command:"
                                 "%s\n output:%s" % (xm_cmd, output))
        elif status != 0:
            raise error.TestFail("Error when attach block device with command:"
                                 "%s\n output:%s" % (xm_cmd, output))

    blocks_attached = 0
    frontend_devices = []
    # Attach all images with "boot_drive=no"
    for image_name in xen_utils.get_sub_dict_names(params, "images"):
        image_params = xen_utils.get_sub_dict(params, image_name)
        if image_params.get("boot_drive") != "no":
                continue
        image_path = domain.get_image_filename(image_params, test.bindir)
        backend_device = ""
        if image_params.get("image_format") == "qcow":
            backend_device = "tap:qcow:%s" % image_path
        elif image_params.get("image_format") == "raw":
            backend_device = "tap:aio:%s" % image_path
        elif image_params.get("image_format") == "lv":
            backend_device = "phy:%s" % image_path
        else:
            raise error.TestError("image params:wrong image_format '%s'"
                                  % image_params.get("image_format"))

        if image_params.get("image_dev"):
            frontend_device = image_params.get("image_dev")
        else:
            raise error.TestError("image params: No image_dev")

        attach_block(vm.name, backend_device, frontend_device, "w")
        # Verify attach success
        if not xen_test_utils.blocks_exist_domainU(vm, frontend_device):
            raise error.TestFail("Block device(backend:%s,frontend:/dev/%s) attach"
                                  " failed" % (backend_device, frontend_device))
        logging.info("Block device(/dev/%s) created" % frontend_device)
        blocks_attached += 1
        frontend_devices.append(frontend_device) 

    def detach_block(domain, device_id):
        xm_cmd = "xm block-detach %s %s" % (domain, device_id)
        status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,
                                           "(xm block-detach) ", timeout=60)
        if status is None:
            raise error.TestFail("Timeout when detach block device with command:"
                                 "%s\n output:%s" % (xm_cmd, output))
        elif status != 0:
            raise error.TestFail("Error when detach block device with command:"
                                 "%s\n output:%s" % (xm_cmd, output))

    if params.get("need_detach_block") == "yes":
        # Detach all block devices attached before
        blocks_xm = xm.get_blocks_info(vm.name)
        for i in range(blocks_attached):
            device_id = blocks_xm.pop()[0]
            detach_block(vm.name, device_id)
            frontend_device = frontend_devices.pop()
            # Verify detach success
            if xen_test_utils.blocks_exist_domainU(vm, frontend_device):
                raise error.TestFail("Detach block device(device_id:%s,frontend:%s)"
                                     " failed" % (device_id, frontend_device))
            logging.info("Block device(/dev/%s) destroyed" % frontend_device)


