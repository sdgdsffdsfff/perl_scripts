import os, logging, commands
from autotest_lib.client.common_lib import error

def run_image_copy(test, params, env):
    """
    Copy guest images from nfs server.
    1) Mount the NFS directory
    2) Check the existence of source image
    3) If existence copy the image from NFS

    @param test: xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    mount_point = '/tmp/images'
    if not os.path.exists(mount_point):
        os.mkdir(mount_point)

    remote_images = params['remote_images']
    mnt_cmd = "mount %s %s -o ro" % (remote_images, mount_point)
    local_images = os.path.join(os.environ['AUTODIR'],'tests/xen/images')
    # always copy a raw image, create a qcow image based on it when needed
    image = os.path.split(params['image_name'])[-1]+'.raw'
    src_path = os.path.join(mount_point, image)
    dst_path = os.path.join(local_images, image)
    cmd = "cp %s %s" % (src_path, dst_path)

    if os.system("mount | grep %s | grep %s" % (mount_point, remote_images)):
        logging.debug("Remote image dir is not mounted, going to mount it")
        s, o = commands.getstatusoutput(mnt_cmd)
        if s != 0:
            raise error.TestError("Failed to mount %s on %s; Reason: %s" %
                                         (remote_images, mount_point, o))
    else:
        logging.debug("Image dir already mounted")

    # Check the existence of source image
    if not os.path.exists(src_path):
        raise error.TestError("Could not found %s in src directory" % src_path)

    logging.debug("Copying image %s..." % image)
    s, o = commands.getstatusoutput(cmd)
    if s != 0:
        raise error.TestFail("Failed to copy image:%s; Reason: %s" % (cmd, o))
    
    # check if we need a qcow image
    if params['image_format'] == 'qcow':
        dst_qcow_image = os.path.split(params['image_name'])[-1]+'.qcow'
        dst_qcow_path = os.path.join(local_images,dst_qcow_image)
        qcow_cmd = "qcow-create 10000 %s %s" % (dst_qcow_path, dst_path)
        
        logging.debug("Create qcow image %s based on %s..." % \
                                                     (dst_qcow_path, dst_path))
        s,o = commands.getstatusoutput(qcow_cmd)
        if s != 0:
            raise error.TestFail("Failed to create qcow image:%s; Reason: %s" \
                                          % (qcow_cmd,o))

