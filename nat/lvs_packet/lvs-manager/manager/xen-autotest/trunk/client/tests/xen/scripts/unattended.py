#!/usr/bin/python
"""
Simple script to setup unattended installs on XEN guests.
"""
# -*- coding: utf-8 -*-
import os, sys, shutil, tempfile, re
import common


class SetupError(Exception):
    """
    Simple wrapper for the builtin Exception class.
    """
    pass


class UnattendedInstall(object):
    """
    Creates a floppy disk image that will contain a config file for unattended
    OS install. Optionally, sets up a PXE install server using qemu built in
    TFTP and DHCP servers to install a particular operating system. The
    parameters to the script are retrieved from environment variables.
    """
    def __init__(self):
        """
        Gets params from environment variables and sets class attributes.
        """
        script_dir = os.path.dirname(sys.modules[__name__].__file__)
        xen_test_dir = os.path.abspath(os.path.join(script_dir, ".."))
        #images_dir = os.path.join(xen_test_dir, 'images')

        #self.deps_dir = os.path.join(xen_test_dir, 'deps')
        #self.unattended_dir = os.path.join(xen_test_dir, 'unattended')

        self.unattended_files = os.environ.get('XEN_TEST_unattended_files')

        #self.qemu_img_bin = os.path.join(xen_test_dir, 'qemu-img')
        self.floppy_mount = tempfile.mkdtemp(prefix='floppy_', dir='/tmp')
        self.floppy_img = os.environ.get('XEN_TEST_fda')


    def create_boot_floppy(self):
        """
        Prepares a boot floppy by creating a floppy image file, mounting it and
        copying an answer file (kickstarts for RH based distros, answer files
        for windows) to it. After that the image is umounted.
        """
        print "Creating boot floppy"

        if not self.unattended_files:
            raise SetupError('unattended_files not defined')

        if not self.floppy_img:
            raise SetupError('fda not defined, dont know how to create floppy image.')

        if os.path.exists(self.floppy_img):
            os.remove(self.floppy_img)

        c_cmd = 'dd if=/dev/zero of="%s" bs=1K count=1440' % self.floppy_img
        if os.system(c_cmd):
            raise SetupError('Could not create floppy image.')

        f_cmd = 'mkfs.msdos -s 1 "%s"' % self.floppy_img
        if os.system(f_cmd):
            raise SetupError('Error formatting floppy image.')

        m_cmd = 'mount -o loop "%s" "%s"' % (self.floppy_img, self.floppy_mount)
        if os.system(m_cmd):
            raise SetupError('Could not mount floppy image.')

        unattended_file_list = self.unattended_files.split(",")
        for f in unattended_file_list:
            f = f.strip()
            src  = f.startswith("unattended/") and f or os.path.join("unattended", f)
            if not os.path.isfile(src):
                raise SetupError('some of unattended files does not exist.')
            if f.endswith('.sif'):
                dest_fname = 'winnt.sif'
            elif f.endswith('.cfg'):
                dest_fname = 'ks.cfg'
            elif f.endswith('.xml'):
                dest_fname = 'autounattend.xml'
            else:
                dest_fname = os.path.basename(f)
            dest = os.path.join(self.floppy_mount, dest_fname)
            shutil.copyfile(src, dest)

        u_cmd = 'umount "%s"' % self.floppy_mount
        if os.system(u_cmd):
            raise SetupError('Could not unmount floppy at %s.' %
                             self.floppy_mount)

        os.chmod(self.floppy_img, 0755)

        print "Boot floppy created successfuly"


    def cleanup(self):
        """
        Clean up previously used mount points.
        """
        print "Cleaning up unused mount points"
        for mount in [self.floppy_mount]:
            if os.path.isdir(mount):
                if os.path.ismount(mount):
                    print "Path %s is still mounted, please verify" % mount
                else:
                    print "Removing mount point %s" % mount
                    os.rmdir(mount)


    def setup(self):
        print "Starting unattended install setup"

        print "Variables set:"
        print "    unattended_files: " + str(self.unattended_files)
        print "    floppy_mount: " + str(self.floppy_mount)
        print "    floppy_img: " + str(self.floppy_img)

        self.create_boot_floppy()
        self.cleanup()
        print "Unattended install setup finished successfuly"


if __name__ == "__main__":
    os_install = UnattendedInstall()
    os_install.setup()
