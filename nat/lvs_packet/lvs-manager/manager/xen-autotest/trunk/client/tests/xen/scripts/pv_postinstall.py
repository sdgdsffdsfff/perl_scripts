"""
Delete kernel and ramdisk files that are useless
"""
import os, sys, logging


def pv_postinstall():
    if os.environ.has_key("XEN_TEST_Del_kernel"):
        kernel_file = os.environ["XEN_TEST_Del_kernel"]
        logging.debug("Delete kernel file %s" % kernel_file)
        os.remove(kernel_file)
    
    if os.environ.has_key("XEN_TEST_Del_ramdisk"):
        ramdisk_file = os.environ["XEN_TEST_Del_ramdisk"]
        logging.debug("Delete ramdisk file %s" % ramdisk_file)
        os.remove(ramdisk_file)

if __name__ == "__main__":
    pv_postinstall()
