import sys, os, time, commands, re, logging, signal, glob
from autotest_lib.client.bin import test
from autotest_lib.client.common_lib import error
import domain, xen_utils, xen_subprocess


def preprocess_image(test, params):
    """
    Preprocess a single image according to the instructions in params.

    @param test: Autotest test object.
    @param params: A dict containing image preprocessing parameters.
    @note: Currently this function just creates an image if requested.
    """
    image_filename = domain.get_image_filename(params, test.bindir)

    create_image = False

    if params.get("force_create_image") == "yes":
        logging.debug("'force_create_image' specified; creating image...")
        create_image = True
    elif (params.get("create_image") == "yes" and not
          os.path.exists(image_filename)):
        logging.debug("Creating image...")
        create_image = True
    
    # Note here we do not implement create_image() function yet
    if create_image and not domain.create_image(params, test.bindir):
        raise error.TestError("Could not create image")


def preprocess_vm(test, params, env, name):
    """
    Preprocess a single VM object according to the instructions in params.
    Start the VM if requested.

    @param test: An Autotest test object.
    @param params: A dict containing VM preprocessing parameters.
    @param env: The environment (a dict-like object).
    @param name: The name of the VM object.
    """
    logging.debug("Preprocessing VM '%s'..." % name)
    vm = xen_utils.env_get_vm(env, name)
    if vm:
        logging.debug("VM object found in environment")
    else:
        logging.debug("VM object does not exist; creating it")
        vm = domain.XenDomain(name, params, test.bindir, env.get("address_cache"))
        xen_utils.env_register_vm(env, name, vm)
    
    start_vm = False

    if params.get("restart_vm") == "yes":
        logging.debug("'restart_vm' specified; (re)starting VM...")
        start_vm = True
    elif params.get("start_vm") == "yes":
        if not vm.is_running():
            logging.debug("VM is not alive; starting it...")
            start_vm = True
        else:
            new_config = vm.make_config(name, params, test.bindir, env, dry_run=True)
            if vm.config and domain.config_equals(vm.config, new_config):
               logging.debug("VM`s xen config is the same to requested one; "
                              "Do not restart it...")
            else:
               logging.debug("VM's xen config differs from requested one; "
                              "restarting it...")
               start_vm = True

    if start_vm and not vm.create(name, params, test.bindir, env):
        if params.get('vm_critical') != 'no':
            raise error.TestError("Could not start VM")

def postprocess_image(test, params):
    """
    Postprocess a single image according to the instructions in params.
    Currently this function just removes an image if requested.

    @param test: An Autotest test object.
    @param params: A dict containing image postprocessing parameters.
    """
    if params.get("remove_image") == "yes":
        domain.remove_image(params, test.bindir)


def postprocess_vm(test, params, env, name):
    """
    Postprocess a single VM object according to the instructions in params.
    Kill the VM if requested.

    @param test: An Autotest test object.
    @param params: A dict containing VM postprocessing parameters.
    @param env: The environment (a dict-like object).
    @param name: The name of the VM object.
    """
    logging.debug("Postprocessing VM '%s'..." % name)
    vm = xen_utils.env_get_vm(env, name)
    if vm:
        logging.debug("VM object found in environment")
    else:
        logging.debug("VM object does not exist in environment")
        return

    if params.get("kill_vm") == "yes":
        kill_vm_timeout = float(params.get("kill_vm_timeout", 0))
        if kill_vm_timeout:
            logging.debug("'kill_vm' specified; waiting for VM to shut down "
                          "before killing it...")
            xen_utils.wait_for(vm.is_dead, kill_vm_timeout, 0, 1)
        else:
            logging.debug("'kill_vm' specified; killing VM...")
        vm.destroy(gracefully = params.get("kill_vm_gracefully") == "yes")


def process_command(test, params, env, command, command_timeout,
                    command_noncritical):
    """
    Pre- or post- custom commands to be executed before/after a test is run

    @param test: An Autotest test object.
    @param params: A dict containing all VM and image parameters.
    @param env: The environment (a dict-like object).
    @param command: Command to be run.
    @param command_timeout: Timeout for command execution.
    @param command_noncritical: If True test will not fail if command fails.
    """
    # Export environment vars
    for k in params.keys():
        os.putenv("XEN_TEST_%s" % k, str(params[k]))
    # Execute command
    logging.info("Executing command '%s'..." % command)
    (status, output) = xen_subprocess.run_fg("cd %s; %s" % (test.bindir,
                                                            command),
                                             logging.debug, "(command) ",
                                             timeout=command_timeout)
    if status != 0:
        logging.warn("Custom processing command failed: '%s'" % command)
        if not command_noncritical:
            raise error.TestError("Custom processing command failed")


def process(test, params, env, image_func, vm_func):
    """
    Pre- or post-process VMs and images according to the instructions in params.
    Call image_func for each image listed in params and vm_func for each VM.

    @param test: An Autotest test object.
    @param params: A dict containing all VM and image parameters.
    @param env: The environment (a dict-like object).
    @param image_func: A function to call for each image.
    @param vm_func: A function to call for each VM.
    """
    # Get list of VMs specified for this test
    vm_names = xen_utils.get_sub_dict_names(params, "vms")
    for vm_name in vm_names:
        vm_params = xen_utils.get_sub_dict(params, vm_name)
        # Get list of images specified for this VM
        image_names = xen_utils.get_sub_dict_names(vm_params, "images")
        for image_name in image_names:
            image_params = xen_utils.get_sub_dict(vm_params, image_name)
            # Call image_func for each image
            image_func(test, image_params)
        # Call vm_func for each vm
        vm_func(test, vm_params, env, vm_name)


def preprocess(test, params, env):
    """
    Preprocess all VMs and images according to the instructions in params.
    Also, collect some host information.

    @param test: An Autotest test object.
    @param params: A dict containing all VM and image parameters.
    @param env: The environment (a dict-like object).
    """
    # Start tcpdump if it isn't already running
    if not env.has_key("address_cache"):
        env["address_cache"] = {}
    if env.has_key("tcpdump") and not env["tcpdump"].is_alive():
        env["tcpdump"].close()
        del env["tcpdump"]
    if not env.has_key("tcpdump"):
        command = "/usr/sbin/tcpdump -npvi any 'dst port 68'"
        logging.debug("Starting tcpdump (%s)...", command)
        env["tcpdump"] = xen_subprocess.xen_tail(
            command=command,
            output_func=_update_address_cache,
            output_params=(env["address_cache"],))
        if xen_utils.wait_for(lambda: not env["tcpdump"].is_alive(),
                              0.1, 0.1, 1.0):
            logging.warn("Could not start tcpdump")
            logging.warn("Status: %s" % env["tcpdump"].get_status())
            logging.warn("Output:" + xen_utils.format_str_for_message(
                env["tcpdump"].get_output()))

   
    # Destroy and remove VMs that are no longer needed in the environment
    requested_vms = xen_utils.get_sub_dict_names(params, "vms")
    for key in env.keys():
        vm = env[key]
        if not xen_utils.is_vm(vm):
            continue
        if not vm.get_name() in requested_vms:
            logging.debug("VM '%s' found in environment but not required for"
                          " test; removing it..." % vm.name)
            vm.destroy()
            del env[key]
    
    # Execute any pre_commands
    if params.get("pre_command"):
        process_command(test, params, env, params.get("pre_command"),
                        int(params.get("pre_command_timeout", "600")),
                        params.get("pre_command_noncritical") == "yes")

    # Preprocess all VMs and images
    process(test, params, env, preprocess_image, preprocess_vm)


def postprocess(test, params, env):
    """
    Postprocess all VMs and images according to the instructions in params.

    @param test: An Autotest test object.
    @param params: Dict containing all VM and image parameters.
    @param env: The environment (a dict-like object).
    """
    process(test, params, env, postprocess_image, postprocess_vm)

    # Execute any post_commands
    if params.get("post_command"):
        process_command(test, params, env, params.get("post_command"),
                        int(params.get("post_command_timeout", "600")),
                        params.get("post_command_noncritical") == "yes")

    # Kill all unresponsive VMs
    if params.get("kill_unresponsive_vms") == "yes":
        logging.debug("'kill_unresponsive_vms' specified; killing all VMs "
                      "that fail to respond to a remote login request...")
        for vm in xen_utils.env_get_all_vms(env):
            if vm.is_running():
                session = vm.remote_login(timeout=30)
                if session:
                    session.close()
                else:
                    vm.destroy(gracefully=False)
    
    # Terminate tcpdump if no VMs are alive
    living_vms = [vm for vm in xen_utils.env_get_all_vms(env) if vm.is_running()]
    if not living_vms and env.has_key("tcpdump"):
        env["tcpdump"].close()
        del env["tcpdump"]


def postprocess_on_error(test, params, env):
    """
    Perform postprocessing operations required only if the test failed.

    @param test: An Autotest test object.
    @param params: A dict containing all VM and image parameters.
    @param env: The environment (a dict-like object).
    """
    params.update(xen_utils.get_sub_dict(params, "on_error"))


def _update_address_cache(address_cache, line):
    if re.search("Your.IP", line, re.IGNORECASE):
        matches = re.findall(r"\d*\.\d*\.\d*\.\d*", line)
        if matches:
            address_cache["last_seen"] = matches[0]
    if re.search("Client.Ethernet.Address", line, re.IGNORECASE):
        matches = re.findall(r"\w*:\w*:\w*:\w*:\w*:\w*", line)
        if matches and address_cache.get("last_seen"):
            mac_address = matches[0].lower()
            logging.debug("(address cache) Adding cache entry: %s ---> %s",
                          mac_address, address_cache.get("last_seen"))
            address_cache[mac_address] = address_cache.get("last_seen")
            del address_cache["last_seen"]
