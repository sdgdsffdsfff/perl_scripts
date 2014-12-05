

list = [
         {
             "name"       : "start",
             "shortname"  : "start",
             "depend"     : [],
             "type"       : "create",
             "domain_name": "test1",
             "uuid"       : "1efb30c3-86fd-9dd7-4934-9b72b6a833fc",
             "maxmem"     :  512,
             "memory"     :  512,
             "vcpus"      :  1,
             "bootloader" : "/usr/bin/pygrub",
             "on_poweroff":  "destroy",
             "on_reboot"  :  "restart",   
             "disk"       :  "tap:aio:/var/lib/libvirt/images/s2.img,xvda,w",
             "vif"        :  "mac=00:16:36:6b:f9:59,bridge=xenbr0,script=vif-bridge",
          },
       ]


    
