#!/usr/bin/python
"""
 Lib for Domain Operation

"""

import sys, time, re, logging, commands, os

from autotest_lib.client.common_lib import error
import xm, xen_utils, xen_subprocess, xen_test_utils

def get_image_filename(params, root_dir):
    """
    Generate an image path from params and root_dir.

    @param params: Dictionary containing the test parameters.
    @param root_dir: Base directory for relative filenames.

    @note: params should contain:
           vbd_name -- the name of the image file, without extension
           image_format -- the format of the image (qcow2, raw etc)
    """
    image_vbd = params.get("image_vbd", "phy")
    image_format = params.get("image_format", "lv")
    vbd_name = params.get("vbd_name", "image")

    if image_vbd == "file_based":
        image_filename = "%s.%s" % (vbd_name, image_format)
        image_filename = xen_utils.get_path(root_dir, image_filename)
    elif image_format == "lv":
        vg_name = params.get("vg_name", "VG")
        vbd_name = vbd_name.split("/")[1]
        image_filename = "/dev/%s/%s" % (vg_name, vbd_name)         
    else:
        raise error.TestError("Physical Partition is not supported currently")   
        
    return image_filename


def create_image(params, root_dir):
    """
    Create an image using qemu_image.

    @param params: Dictionary containing the test parameters.
    @param root_dir: Base directory for relative filenames.

    @note: params should contain:
           image_name -- the name of the image file, without extension
           image_format -- the format of the image (qcow, raw etc)
           image_size -- the requested size of the image (a string
           qemu-img can understand, such as '10G')
    """
#    qemu_img_cmd = xen_utils.get_path(root_dir, params.get("qemu_img_binary",
#                                                           "qemu-img"))
    format = params.get("image_format", "raw")
    size = params.get("image_size", "6G")
    image_filename = get_image_filename(params, root_dir)
    size_M = int(re.findall("^\d+", size)[0])*1024

    if format == "raw":
        # dd if=/dev/zero of=xenguest.img bs=512 count=1;\
        # dd if=/dev/zero of=xenguest.img bs=512 count=0 seek=6144*1024*1024/2 
        create_img_cmd = params.get("dd_binary", "dd")
        create_img_cmd += " if=/dev/zero"

        create_img_cmd += " of=%s" % image_filename

        create_img_cmd += " bs=512"

        create_img_cmd = create_img_cmd + " count=1" + " ; "\
                         + create_img_cmd + " count=0"

        size_byte = size_M * 1024 * 1024 / 512

        create_img_cmd += " seek=%s" % size_byte

    elif format == "qcow":

        create_img_cmd = params.get("qcow_create_binary", "qcow-create")

        create_img_cmd += " %sM" % size_M

        create_img_cmd += " %s" % image_filename       

    elif format == "lv":

        create_img_cmd = params.get("lv_create_binary", "lvcreate")

        create_img_cmd += " -L %sM" % size_M

        create_img_cmd += " -n %s %s" % (image_filename, params.get("vg_name", "VG"))

    else:
        logging.error("Won't create image,given format is not supported by now")

    logging.debug("Running img-create command:\n%s" % create_img_cmd)
    (status, output) = xen_subprocess.run_fg(create_img_cmd, logging.debug,
                                         "(img-create) ", timeout=120)

    if status is None:
        logging.error("Timeout elapsed while waiting for img-create command "
                      "to complete:\n%s" % create_img_cmd)
        return None
    elif status != 0:
        logging.error("Could not create image; "
                      "img-create command failed:\n%s" % create_img_cmd)
        logging.error("Status: %s" % status)
        logging.error("Output:" + xen_utils.format_str_for_message(output))
        return None

    if not os.path.exists(image_filename):
        logging.error("Image could not be created for some reason; "
                      "img-create command:\n%s" % create_img_cmd)
        return None

    logging.info("Image created in %s" % image_filename)
    return image_filename


def remove_image(params, root_dir):
    """
    Remove an image file.

    @param params: A dict
    @param root_dir: Base directory for relative filenames.

    @note: params should contain:
           image_name -- the name of the image file, without extension
           image_format -- the format of the image (qcow, raw etc)
    """
    image_filename = get_image_filename(params, root_dir)
    image_format = params.get("image_format", "lv")
    logging.debug("Removing image file %s..." % image_filename)
    if os.path.exists(image_filename):
        if image_format == "lv":
            realpath = os.readlink(image_filename)
            cmd = "lvremove %s -f" % realpath
            os.system(cmd)
        else:
            os.unlink(image_filename)
    else:
        logging.debug("Image file %s not found")


class XenConfig:
    """An object to help create a xen-compliant config file"""
    def __init__(self):
        self.defaultOpts = {}

        # These options need to be lists
        self.defaultOpts["disk"] = []
        self.defaultOpts["vif"]  = []
        self.defaultOpts["vfb"] = []
        
        self.opts = self.defaultOpts


    def to_string(self):
        """Convert this config to a string for writing out
        to a file"""
        string = "# Xen configuration generated by xen-autotest\n"
        for k, v in self.opts.items():
            if isinstance(v, int):
                piece = "%s = %i" % (k, v)
            elif isinstance(v, list) and v:
                piece = "%s = %s" % (k, v)
            elif isinstance(v, str) and v:
                piece = "%s = \"%s\"" % (k, v)
            else:
                piece = None

            if piece:
                string += "%s\n" % piece

        return string


    def write(self, filename):
        """Write this config out to filename"""
        output = file(filename, "w")
        output.write(self.to_string())
        output.close()


    def __str__(self):
        """When used as a string, we represent ourself by a config
        filename, which points to a temporary config that we write
        out ahead of time"""
        filename = "/tmp/xm-test.conf"
        self.write(filename)
        return filename


    def set_opt(self, name, value):
        """Set an option in the config"""
        if name in self.opts.keys() and isinstance(self.opts[name] ,
                                        list) and not isinstance(value, list):
                self.opts[name] = [value]
        # "extra" is special so append to it.
        elif name == "extra" and name in self.opts.keys():
            self.opts[name] += " %s" % (value)
        else:
            self.opts[name] = value


    def app_opt(self, name, value):
        """Append a value to a list option"""
        if name in self.opts.keys() and isinstance(self.opts[name], list):
            self.opts[name].append(value)


    def get_opt(self, name):
        """Return the value of a config option"""
        if name in self.opts.keys():
            return self.opts[name]
        else:
            return None


    def set_opts(self, opts):
        """Batch-set options from a dictionary"""
        for k, v in opts.items():
            self.setOpt(k, v)


    def clear_opts(self, name=None):
        """Clear one or all config options"""
        if name:
            if self.opts.has_key(name):
                del self.opts[name]
        else:
            self.opts.clear()

def config_equals(config_src, config_dst):
    return config_src.opts == config_dst.opts



class XenDomain:

    def __init__(self, name, params, root_dir, address_cache):
        """Create a domain object.
        """
        
        self.name = name
        self.config = None
        
        self.params = params

        self.root_dir = root_dir
        self.address_cache = address_cache
        self.macaddr = []
        self.mac_prefix = params.get('mac_prefix')
        
        # set the type of Domain
        # @pv:        PV guest
        # @hvm_linux: RHEL HVM guest 
        # @hvm_win:   Windows HVM guest
        self.type = self.params.get("vm_type")        
        
        s, o = commands.getstatusoutput("ifconfig eth0")
        if s == 0:
            mac = re.findall("HWaddr (\S*)", o)[0]
            self.mac_prefix = mac[0:2] + mac[5:] + ':'

        
    def create(self, name=None, params=None, root_dir=None, env=None):
        
        self.destroy()

        if name is not None:
            self.name = name
        if params is not None:
            self.params = params
        if root_dir is not None:
            self.root_dir = root_dir

        config = self.make_config(env=env, dry_run=False)
        self.config = config
        
        logging.info("Trying to create domain: %s" % self.get_name())
        
        xm_cmd = "xm create %s" % self.config

        for key, val in self.config.opts.iteritems():
            logging.debug("\t%s = %s" % (key, val))

        ret, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm create) ", timeout=60)

        if ret != 0:
            raise error.TestError("Failed to create domain:\n'%s'" % output)
        
        logging.info("domain created: %s" % self.get_name())

        # Make sure domain is alive after a while
        time.sleep(3)
        if self.is_dead():
            logging.info("domain %s disappear after created" % self.get_name())
            return False

        return True

 
    def stop(self):
        prog = "xm"
        cmd = " shutdown "

        xm_cmd = prog + cmd + self.name

        ret, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm shutdown) ", timeout=60)
        return ret


    def reboot(self):
        prog = "xm"
        cmd = " reboot "

        xm_cmd = prog + cmd + self.name

        ret, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm reboot) ", timeout=60)
        return ret


    def destroy(self, gracefully=True, free_macaddr=True):
        """
        Destroy the VM.

        If gracefully is True, first attempt to shutdown the VM via xm shutdown
        If that fails, just destroy the vm via xm destroy

        @param gracefully: Whether an attempt will be made to end the VM
                via xm shutdown before trying to destroy the vm via xm destroy
        """
        try:
            # Is it already dead?
            if self.is_dead():
                logging.debug("VM is already down")
                return

            if gracefully:
                # Try to stop the VM first
                logging.debug("Trying to shutdown VM via xm shutdown...")
                self.stop()
                # Check if VM is dead
                if xen_utils.wait_for(self.is_dead, 60, 1, 1):
                   logging.debug("VM is down")
                   if free_macaddr:
                       self.free_mac_address()
                   return
            
            # If the VM isn't dead yet...
            logging.debug("kill it via xm destroy")
            self.force_destroy()
            # Wait for the VM to be really dead
            if xen_utils.wait_for(self.is_dead, 10, 0.5, 0.5):
                logging.debug("VM is down")
                if free_macaddr:
                    self.free_mac_address()
                return
        finally:
            #raise error.TestError("Cannot destory a VM")
            pass


    def force_destroy(self, gracefully=True):
        prog = "xm"
        cmd = " destroy "

        xm_cmd = prog + cmd + self.name
        ret, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                           "(xm destroy) ", timeout=60)
        return ret


    def get_params(self):
        """
        Return the VM's params dict. Most modified params take effect only
        upon VM.create().
        """
        return self.params


    def get_name(self):
        return self.name


    def get_id(self):
        return xm.get_dom_id(self.get_name());


    def get_domaintype(self):
        return self.type

    
    def get_memsize(self):
        """
        Get Memory Size from within DomainU
        """
        session = xen_test_utils.wait_for_login(self)

        try:
            if not session.is_responsive():
                raise error.TestError("Get an unresponsive session")
            
            cmd = self.params.get("mem_chk_cmd")

            status, output = session.get_command_status_output(cmd)
            if status is None:
               raise error.TestError("Error when get memory size" 
                                    "from within domainU:%s" % output) 
            if status != 0:
               raise error.TestError("Error when get memory size" 
                                    "from within domainU:%s" % output)

            output=output.strip(' \r\n')
            logging.debug("got mem_chk_cmd output: '%s'" % output)
            if self.get_domaintype() in ['pv','hvm_linux','hvm_win']:
                return int(output)

        finally:
            session.close()       


    def is_running(self):
        return xm.is_DomainRunning(self.name)


    def is_dead(self):
        return not self.is_running()


    def free_mac_address(self, mac_num=0):
        for mac in self.macaddr[mac_num:]:
            xen_utils.put_mac_to_pool(self.root_dir, mac)
            self.macaddr.remove(mac)


    def make_config(self, name=None, params=None, root_dir=None, env=None, dry_run=False):
        """
        Generate a config instance for creating vm. Get reference of all 
        parameters via:
        # xm create --help-config
        @ dry_run: if dry_run is True, then just use this method to generate 
                   a config but to it to create a vm; otherwise it is used to
                   create vm and may modify env 
        """
        if name is None:
            name = self.name
        if params is None:
            params = self.params
        if root_dir is None:
            root_dir = self.root_dir

        # Start constructing config
        config = XenConfig()

        # Set name of VM
        config.set_opt("name",name)

        # Check if there is case specified value
        xen_utils.case_value_substitution(params, 'case_value_')

        # image
        for image_name in xen_utils.get_sub_dict_names(params, "images"):
            image_params = xen_utils.get_sub_dict(params, image_name)
            if image_params.get("boot_drive") == "no":
                continue
            image_path = get_image_filename(image_params,root_dir)
            
            image_str = ""
            
            # UNAME
            if image_params.get("image_vbd") == "phy":
                image_str = "phy:%s" % image_path
            elif image_params.get("image_vbd") == "file_based":
                if image_params.get("vbd_type") == "loopback":
                    image_str = "file:%s" % image_path
                elif image_params.get("vbd_type") == "blktap":
                    if image_params.get("image_format") == "qcow":
                        image_str = "tap:qcow:%s" % image_path
                    elif image_params.get("image_format") == "raw":
                        image_str = "tap:aio:%s" % image_path
                    else:
                        raise error.TestError("image params:\
                               wrong image_format '%s'" % \
                               image_params.get("image_format"))
                else:
                    raise error.TestError("image params:\
                               wrong vbd_type '%s'" % \
                               image_params.get("vbd_type"))
            else:
                raise error.TestError("image params:\
                               wrong image_vbd '%s'" % \
                               image_params.get("image_vbd"))

            # the backend option 'overrides' the options above
            # for arbitrary testing purpose
            backend = image_params.get("backend")
            if backend:
                image_str = "%s:%s" % (backend,image_path)
             
            # DEV
            if image_params.get("image_dev"):
                image_str += ",%s" % image_params.get("image_dev")
            else:
                raise error.TestError("image params: No image_dev")
  
            # MODE
            if image_params.get("image_mode"):
                image_str += ",%s" % image_params.get("image_mode")
            else:
                raise error.TestError("image params: No image_mode")
    
            # Append this string to config
            config.app_opt("disk",image_str); 

        # CDROM. Only *ONE* CDROM for each guest supported
        if params.get("cdrom") and params.get("boot_drive_cdrom", "yes") == "yes":
            # Make it a abs path
            cdrom = params.get("cdrom")
            cdrom = xen_utils.get_path(self.root_dir,cdrom)
            cdrom_str = "%s:%s,%s:cdrom,r" % (params.get("prefix_cdrom"),\
                               cdrom, params.get("dev_cdrom"))
            # Append this string to config
            config.app_opt("disk",cdrom_str); 
        
        # network
        # Give a mac address for each nic and store in self.macaddr
        nic_num = len(xen_utils.get_sub_dict_names(params, "nics"))
        mac_num = nic_num - len(self.macaddr)
        if mac_num >= 0:
            for i in range(mac_num):
                macaddr = xen_utils.get_mac_from_pool(self.root_dir,
                                                      self.mac_prefix)
                self.macaddr.append(macaddr)
        else:
            self.free_mac_address(mac_num)
        
        # The ith nic
        index = 0
        
        for nic_name in xen_utils.get_sub_dict_names(params, "nics"):
            nic_params = xen_utils.get_sub_dict(params, nic_name)
            
            # vif
            # At least mac, script and bridge should be provided
            vif = ""
            mac = self.get_mac(index)
            nic_script = nic_params.get("nic_script","vif-bridge")
            nic_bridge = nic_params.get("nic_bridge","xenbr0")
            vif = "mac=%s,script=%s,bridge=%s" % (mac,nic_script,nic_bridge)
            
            index += 1
            
            if nic_params.get("nic_backend"):
               vif += ",backend=%s" % nic_params.get("nic_backend")

            if nic_params.get("nic_model"):
               vif += ",model=%s" % nic_params.get("nic_model")

            if nic_params.get("nic_ip"):
               vif += ",ip=%s" % nic_params.get("nic_ip")

            if nic_params.get("nic_type"):
               vif += ",type=%s" % nic_params.get("nic_type")

            if nic_params.get("nic_vifname"):
               vif += ",vifname=%s" % nic_params.get("nic_vifname")

            # Append it to config
            config.app_opt("vif",vif)
        
        # Set kernel, ramdisk and extra option before going through all 
        # the other options for PV Guest OS Install. Note here that the 
        # going through process will overwrite existing value if eiher
        # kernel or ramdisk is given in params. extra is special, for its
        # new value is always appended to it.
        if env:
            for key in ["kernel", "ramdisk", "extra"]:
                if env.has_key(key):
                    value = env[key]
                    config.set_opt(key,value)
                    if not dry_run:
                        if key in ["kernel", "ramdisk"]:
                            os.putenv("XEN_TEST_Del_%s" % key, value)
                        del env[key]
                
        
        config_params = ["memory","vncpasswd","vncviewer","vncconsole",\
                         "bootloader", "bootentry","bootargs","kernel",\
                         "ramdisk", "features","builder","memory",\
                         "maxmem", "shadow_memory","cpu","cpus",\
                         "pae","timer_mode","acpi","apic",\
                         "vcpus","cpu_cap","cpu_weight","restart",\
                         "on_poweroff","on_reboot","on_crash","blkif",\
                         "netif","tpmif","pci","ioports",\
                         "irq","usbport","root",\
                         "extra","ip","gateway","netmask",\
                         "hostname","interface","dhcp","nfs_server",\
                         "nfs_root","device_model","fda","fdb",\
                         "serial","localtime","keymap","usb",\
                         "usbdevice","stdvga","isa","boot",\
                         "nographic","soundhw","vnc","vncdisplay",\
                         "vnclisten","vncunused","sdl","display",\
                         "xauthority","uuid","vfb"]
         
        for param_name in config_params:
            param_value = params.get(param_name)
            if param_value:
               if param_name == "fda" or param_name == "fdb":
                   param_value = xen_utils.get_path(self.root_dir,param_value)
               config.set_opt(param_name,param_value) 
      
        # Make sure bootloader is not in config when do PV os install
        if config.get_opt("kernel") and config.get_opt("ramdisk"):
            if config.get_opt("bootloader"):
                logging.info("Remove bootloader option")
                config.clear_opts("bootloader")
 
        return config


    def get_mac(self, index=0):
        """
        return the the mac address of the first nic in spicific network:
        """
        return self.macaddr[index]


    def get_address(self, index=0):
        """
        Return the address of a NIC of the guest, in host space.

        @param index: Index of the NIC whose address is requested.
        """
        # Check if guest has static ip
        if self.params.get("static_net", "no") == "yes":
            return self.params.get("static_ip")

        mac = self.macaddr[index].lower()

        if not mac:
            logging.debug("MAC address unavailable")
            return None

        # Get the IP address from the cache
        ip = self.address_cache.get(mac)
        if not ip:
            logging.debug("Could not find IP address for MAC address: "
                          "%s" % mac)
            return None

        # Make sure the IP address is assigned to this guest
        if not xen_utils.verify_ip_address_ownership(ip, mac):
            logging.debug("Could not verify MAC-IP address mapping: "
                          "%s ---> %s" % (mac, ip))
            return None

        return ip


    def remote_login(self, nic_index=0, timeout=10):
        """
        Log into the guest via SSH/Telnet/Netcat.
        If timeout expires while waiting for output from the guest (e.g. a
        password prompt or a shell prompt) -- fail. 

        @param nic_index: The index of the NIC to connect to.
        @param timeout: Time (seconds) before giving up logging into the
                guest.
        @return: xen_spawn object on success and None on failure.
        """
        username = self.params.get("username", "")
        password = self.params.get("password", "")
        prompt = self.params.get("shell_prompt", "[\#\$]")
        linesep = eval("'%s'" % self.params.get("shell_linesep", r"\n"))
        client = self.params.get("shell_client")
        address = self.get_address(nic_index)
        port = self.params.get("shell_port")

        if not address or not port:
            logging.debug("IP address or port unavailable")
            return None

        if client == "ssh":
            session = xen_utils.ssh(address, port, username, password,
                                    prompt, linesep, timeout)
        elif client == "telnet":
            session = xen_utils.telnet(address, port, username, password,
                                       prompt, linesep, timeout)
        elif client == "nc":
            session = xen_utils.netcat(address, port, username, password,
                                       prompt, linesep, timeout)

        if session:
            session.set_status_test_command(self.params.get("status_test_"
                                                            "command", ""))
        return session


    def copy_files_to(self, local_path, remote_path, nic_index=0, timeout=300):
        """
        Transfer files to the guest.

        @param local_path: Host path
        @param remote_path: Guest path
        @param nic_index: The index of the NIC to connect to.
        @param timeout: Time (seconds) before giving up on doing the remote
                copy.
        """
        username = self.params.get("username", "")
        password = self.params.get("password", "")
        client = self.params.get("file_transfer_client")
        address = self.get_address(nic_index)
        port = self.params.get("file_transfer_port")

        if not address or not port:
            logging.debug("IP address or port unavailable")
            return None

        if client == "scp":
            return xen_utils.scp_to_remote(address, port, username, password,
                                           local_path, remote_path, timeout)


    def copy_files_from(self, remote_path, local_path, nic_index=0, timeout=300):
        """
        Transfer files from the guest.

        @param local_path: Guest path
        @param remote_path: Host path
        @param nic_index: The index of the NIC to connect to.
        @param timeout: Time (seconds) before giving up on doing the remote
                copy.
        """
        username = self.params.get("username", "")
        password = self.params.get("password", "")
        client = self.params.get("file_transfer_client")
        address = self.get_address(nic_index)
        port = self.params.get("file_transfer_port")

        if not address or not port:
            logging.debug("IP address or port unavailable")
            return None

        if client == "scp":
            return xen_utils.scp_from_remote(address, port, username, password,
                                             remote_path, local_path, timeout)


if __name__ == "__main__":

    c = XenConfig()

    opts = {"name"       : "test1",
            "uuid"       : "1efb30c3-86fd-9dd7-4934-9b72b6a833fc",
            "maxmem"     :  512,
            "memory"     :  512,
            "vcpus"      :  1,
            "bootloader" : "/usr/bin/pygrub",
            "on_poweroff":  "destroy",
            "on_reboot"  :  "restart",   
            "disk"       :  "tap:aio:/var/lib/libvirt/images/s2.img,xvda,w",
            "vif"        :  "mac=00:16:36:6b:f9:59,bridge=xenbr0,script=vif-bridge",
            }
    c.setOpts(opts)
    
    domain = XenDomain(c)    
    
    domain.start()
    
    print str(c)



#    c.write("/tmp/foo.conf")

#    d = XmTestDomain();
#
#    d.start();

