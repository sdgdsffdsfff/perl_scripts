import os, logging, commands
from autotest_lib.client.common_lib import error
import xen_test_utils, xm, xen_subprocess, domain

def run_image_bootstrap(test, params, env):
    """
    Copy guest images from nfs server.
    1) mkfs on the target disk image
    2) mount disk image on a local mount point
    3) get remote tarball from hadoop and unpack it into the disk image

    @param test: xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary qith test environment.
    """
    format = params.get("image_format", "raw")
    hadoop_cmd = params.get("hadoop_binary", "/usr/local/hadoop/bin/hadoop") 
    hadoop_storage = params.get("hadoop_storage", "/home/vm/template")
    hadoop_tarball = params.get("hadoop_tarball", "centos5.4")

    status, output = xen_subprocess.run_fg("mktemp -d", timeout=60)
    if status is None:
        raise error.TestFail("Time eslapsed while make temp dir")
    elif status != 0:
        raise error.TestFail("Got error due to %s" % output)
    else:
        tmpdir = output.split("\n")[0]

    try:
        # Get path to vbd
        image_filename = domain.get_image_filename(params, test.bindir)

        if not os.path.exists(image_filename):
            domain.create_image(params, test.bindir)

        # mkfs on vbd
        logging.info("Making filesystem on %s" % image_filename)
        mkfs_cmd = "mke2fs -qm0 %s" % image_filename
        status, output = xen_subprocess.run_fg(mkfs_cmd, timeout=60)
        if status is None:
            raise error.TestFail("Time eslapsed while making filesystem")
        elif status != 0:
            raise error.TestFail("Making filesystem got error due to %s" % output)

        # mount
        if format == "lv":
            blkdev = image_filename 
        elif format == "raw":
            status, output = xen_subprocess.run_fg("losetup -f", timeout=60)
            if status is None:
                raise error.TestFail("Time eslapsed while doing losetup -f")
            elif status != 0:
                raise error.TestFail("Doing losetup -f got error due to %s" % output)
            else:
                blkdev = output
            
            losetup_cmd = "losetup %s %s" % (blkdev, image_filename)    
            status, output = xen_subprocess.run_fg(losetup_cmd, timeout=60)
            if status is None:
                raise error.TestFail("Time eslapsed while doing losetup")
            elif status != 0:
                raise error.TestFail("Doing losetup got error due to %s" % output)
        else:
            raise error.TestError("Format %s is not supported for image_bootstrap" % format)

        mount_cmd = "mount %s %s" % (blkdev, tmpdir)
        status, output = xen_subprocess.run_fg(mount_cmd, timeout=60)
        if status is None:
            raise error.TestFail("Time eslapsed while mount %s to %s" \
                                   % (blkdev, tmpdir))
        elif status != 0:
            raise error.TestFail("Got error while mount due to %s" % output)
        
        logging.info("%s is mounted on %s" % (image_filename, tmpdir))

        # 
        hadoop_cmd = "%s fs -cat %s/%s" % (hadoop_cmd, hadoop_storage, hadoop_tarball)
        tar_cmd = "%s | tar xf - -C %s" % (hadoop_cmd, tmpdir)

        logging.info("Try to unpack tarball: %s" % tar_cmd)
        status, output = xen_subprocess.run_fg(tar_cmd, timeout=600)
        if status is None:
            raise error.TestFail("Time eslapsed while unpacking tar package %s" \
                                  % hadoop_tarball)
        elif status != 0:
            raise error.TestFail("Unable to unpacking tar package %s due to %s" \
                                  % (hadoop_tarball, output))

        logging.info("Filesystem structure after unpacking tarball:")
        output = commands.getoutput("ls %s" % tmpdir)
        logging.info(output)      

        if params.get("static_net", "no") == "yes":
            logging.info("Static network specified, configure network...")
            ip = params.get("static_ip")
            gw = params.get("static_gw")
            mask = params.get("static_mask")
            cfg_file = "%s/etc/sysconfig/network-scripts/ifcfg-eth0" % tmpdir
            file = open(cfg_file, 'w+', 0)
            if file is None:
                raise error.TestError("Can not open %s" % cfg_file)
            file.write("DEVICE=eth0\nBOOTPROTO=static\nIPADDR=%s\nNETMASK=%s\nONBOOT=yes\nGATEWAY=%s" %\
                        (ip, mask, gw))
            file.seek(0)
            logging.debug("Guest Network is configured as:")
            for line in file:
                logging.debug(line)
            file.close()

    finally:
        os.system("umount -f %s" % tmpdir)
        if format == "raw":
            os.system("losetup -d %s" % blkdev)
        if os.path.exists(tmpdir):
            os.rmdir(tmpdir)
