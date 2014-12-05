import os, commands, logging
import xen_utils
from autotest_lib.client.common_lib import error

def run_pv_preinstall(test, params, env):
    """
    XEN pv preinstall test:
    1) Download kernel and ramdisk
    2) Rename their name to unique name
    3) Store kernel/ramdisk/extra in env
    4) Keys in env can be used by pv_install
 
    @param test: xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    if params.has_key("tree"):
        tree = params.get("tree")
    else:
        raise error.TestError("No tree specified in config file.")

    kernel = params.get("kernel", "images/xen/vmlinuz")
    ramdisk = params.get("ramdisk", "images/xen/initrd.img")

    kernel_local = get_remote_file(tree, kernel)
    ramdisk_local = get_remote_file(tree, ramdisk)

    # Add kernel file location to env
    if kernel_local is None:
        raise error.TestError("No kernel file got from url: %s"
                              % os.path.join(tree, kernel))
    else:
        env["kernel"] = kernel_local
        logging.debug("Set env[\"kernel\"]: %s" % env["kernel"])

    # Add ramdisk file location to env
    if ramdisk_local is None:
        raise error.TestError("No ramdisk file got from url: %s"
                              % os.path.join(tree, ramdisk))
    else:
        env["ramdisk"] = ramdisk_local 
        logging.debug("Set env[\"ramdisk\"]: %s" % env["ramdisk"])

    # Add extra instruction info to env
    if params.has_key("pv_kickstart"):
       # Get address of nfs server deployed locally
       # IP
       hostip = xen_utils.get_hostip_by_if("eth0")
       # Path
       ks_path = os.path.join(test.bindir, "unattended/pv_ks/%s" 
                                              % params.get("pv_kickstart"))

       nfs_ks = "nfs:%s:%s" % (hostip, ks_path) 


       env["extra"] = "ks=%s" % nfs_ks
       logging.debug("Set env[\"extra\"]: %s" % env["extra"])


def get_remote_file(basedir, file):

    file_url = os.path.join(basedir, file)

    tmp_dir = "/var/lib/xen_autotest"
    if not os.path.exists(tmp_dir):
        os.mkdir(tmp_dir)

    file_local = os.path.join(tmp_dir,"boot_") + os.path.basename(file) + "." \
                 + xen_utils.generate_random_string(6)

    wget_command = "wget %s -O %s" % (file_url, file_local)
    (status, output) = commands.getstatusoutput(wget_command)

    if not status:
        return file_local
    else:
        raise error.TestError("Wget file from remote place failed,"
                              "with command: %s" % wget_command)



