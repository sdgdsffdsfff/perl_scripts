import os
import logging
import xen_subprocess

def run_qcow(test, params, env):

    cmd = params['cmd']

    if cmd == 'img2qcow':
        src = "%s/%s.raw" % (test.bindir, params['image_name'])
        dest = "/tmp/test.qcow"
        dfmt = "qcow"

    elif cmd == 'qcow2raw':
        # use the image produced by the img2qcow case
        src = "/tmp/test.qcow"
        dest = "/tmp/test.raw"
        dfmt = "raw"

    s = os.system( "%s %s %s" % (cmd, dest, src) )
    assert s==0

    s,o = xen_subprocess.run_fg("qemu-img info "+dest, logging.debug)

    # the latter case
    if cmd == 'qcow2raw':
        os.unlink(src)
        os.unlink(dest)

    assert s==0
    i = o.find("file format: "+dfmt)
    assert i>=0
