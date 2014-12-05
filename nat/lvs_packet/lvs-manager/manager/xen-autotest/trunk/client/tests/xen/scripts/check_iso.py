"""
Mount nfs server where store iso and kickstart file
Check the existance of desired file
"""
import os, sys, commands, logging
import common
from autotest_lib.client.common_lib import error

def nfs_mount():
    """
    Mount the NFS directory
    """
    mount_dest_dir = os.environ['ISO_DIR']
    if not os.path.exists(mount_dest_dir):
        logging.info("isos dir doesn`t exist, create it...")
        os.mkdir(mount_dest_dir)
   
    if os.environ.has_key('XEN_TEST_nfs_iso'):
        src = os.environ['XEN_TEST_nfs_iso']
    else:
        raise error.TestError("nfs_iso doesn`t exist")

    mnt_cmd = "mount %s %s -o ro" % (src, mount_dest_dir)

    if os.system("mount | grep %s | grep %s" % (mount_dest_dir, src)):
        logging.debug("ISO dir is not mounted, going to mount it")
        s, o = commands.getstatusoutput(mnt_cmd)
        if s != 0:
            raise error.TestError("Failed to mount %s on %s; Reason: %s" %
                                         (src, mount_dest_dir, o))
    else:
        logging.debug("ISO dir already mounted")
   

def check():
    """
    Mount nfs server to get iso and kick file
    1) Mount the NFS directory
    2) Check the existence of iso and kickstart file

    @param test: xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    
    # Mount NFS Dir
    nfs_mount()
    
    pwd = os.path.join(os.environ['AUTODIR'],'tests/xen/')
    
    # Check ISO File   
    if os.environ.has_key('XEN_TEST_cdrom'):
        iso = os.environ['XEN_TEST_cdrom']
    else:
        raise error.TestError("cdrom doesn`t exist")
    iso_path = os.path.join(pwd, iso)
    if not os.path.exists(iso_path):
        raise error.TestError("ISO file %s doesn`t exist" % iso_path)
    logging.debug("Find the ISO file: %s" % iso_path)
    
    # Check kickstart File   
    '''
    if os.environ.has_key('XEN_TEST_fda'):
        floppy = os.environ['XEN_TEST_fda']
    else:
        raise error.TestError("fda doesn`t exist")
    floppy_path = os.path.join(pwd, floppy)
    if not os.path.exists(floppy_path):
        raise error.TestError("Kickstart file %s doesn`t exist" % floppy_path)
    logging.debug("Find the kickstart file: %s" % floppy_path)
    '''


if __name__=="__main__":
    check()
