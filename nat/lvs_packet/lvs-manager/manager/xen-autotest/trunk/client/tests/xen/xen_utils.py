"""
Xen test utility functions.

"""

import thread, subprocess, time, string, random, socket, os, signal
import select, re, logging, commands, cPickle, pty, fcntl, shelve
from autotest_lib.client.bin import utils
from autotest_lib.client.common_lib import error

import xen_subprocess

def dump_env(obj, filename):
    """
    Dump Xen test environment to a file.

    @param filename: Path to a file where the environment will be dumped to.
    """
    file = open(filename, "w")
    cPickle.dump(obj, file)
    file.close()


def load_env(filename, default=None):
    """
    Load test environment from an environment file.

    @param filename: Path to a file where the environment was dumped to.
    """
    try:
        file = open(filename, "r")
    except:
        return default
    obj = cPickle.load(file)
    file.close()
    return obj


def get_sub_dict(dict, name):
    """
    Return a "sub-dict" corresponding to a specific object.

    Operate on a copy of dict: for each key that ends with the suffix
    "_" + name, strip the suffix from the key, and set the value of
    the stripped key to that of the key. Return the resulting dict.

    @param name: Suffix of the key we want to set the value.
    """
    suffix = "_" + name
    new_dict = dict.copy()
    for key in dict.keys():
        if key.endswith(suffix):
            new_key = key.split(suffix)[0]
            new_dict[new_key] = dict[key]
    return new_dict


def get_sub_dict_names(dict, keyword):
    """
    Return a list of "sub-dict" names that may be extracted with get_sub_dict.

    This function may be modified to change the behavior of all functions that
    deal with multiple objects defined in dicts (e.g. VMs, images, NICs).

    @param keyword: A key in dict (e.g. "vms", "images", "nics").
    """
    names = dict.get(keyword)
    if names:
        return names.split()
    else:
        return []


# Functions related to MAC/IP addresses

def random_mac():
    mac=[0x00,0x16,0x30,
         random.randint(0x00,0x09),
         random.randint(0x00,0x09),
         random.randint(0x00,0x09)]
    return ':'.join(map(lambda x: "%02x" %x,mac))


def get_mac_from_pool(root_dir, prefix='00:11:22:33:44:'):
    """
    random generated mac address.
    1) First try to generate macaddress based on the mac address prefix.
    2) And then try to use total random generated mac address.
    """

    lock_filename = os.path.join(root_dir, "mac_lock")
    lock_file = open(lock_filename, 'w')
    fcntl.lockf(lock_file.fileno() ,fcntl.LOCK_EX)
    env_filename = os.path.join(root_dir, "address_pool")
    env = shelve.open(env_filename, writeback=False)

    mac_pool = env.get("macpool")

    if not mac_pool:
        mac_pool = []

    find = False
    for i in range(0,254):
        mac = prefix + "%02x" % i
        if not mac in mac_pool:
            find = True
            mac_pool.append(mac)
            break

    while not find:
        mac=random_mac()
        if not mac in mac_pool:
            find = True
            mac_pool.append(mac)

    env["macpool"] = mac_pool
    logging.debug("generating mac addr %s " % mac)

    env.close()
    fcntl.lockf(lock_file.fileno(), fcntl.LOCK_UN)
    lock_file.close()
    return mac


def put_mac_to_pool(root_dir, mac):
    """
    Put the macaddress back to address pool
    """

    lock_filename = os.path.join(root_dir, "mac_lock")
    lock_file = open(lock_filename, 'w')
    fcntl.lockf(lock_file.fileno() ,fcntl.LOCK_EX)
    env_filename = os.path.join(root_dir, "address_pool")
    env = shelve.open(env_filename, writeback=False)

    mac_pool = env.get("macpool")

    if not mac_pool or (not mac in mac_pool):
        logging.debug("Try to free a macaddress does no in pool")
        logging.debug("macaddress is %s" % mac)
        logging.debug("pool is %s" % mac_pool)
    else:
        mac_pool.remove(mac)

    env["macpool"] = mac_pool
    logging.debug("freeing mac addr %s " % mac)

    env.close()
    fcntl.lockf(lock_file.fileno(), fcntl.LOCK_UN)
    lock_file.close()
    return mac


def mac_str_to_int(addr):
    """
    Convert MAC address string to integer.

    @param addr: String representing the MAC address.
    """
    return sum(int(s, 16) * 256 ** i
               for i, s in enumerate(reversed(addr.split(":"))))


def mac_int_to_str(addr):
    """
    Convert MAC address integer to string.

    @param addr: Integer representing the MAC address.
    """
    return ":".join("%02x" % (addr >> 8 * i & 0xFF)
                    for i in reversed(range(6)))


def ip_str_to_int(addr):
    """
    Convert IP address string to integer.

    @param addr: String representing the IP address.
    """
    return sum(int(s) * 256 ** i
               for i, s in enumerate(reversed(addr.split("."))))


def ip_int_to_str(addr):
    """
    Convert IP address integer to string.

    @param addr: Integer representing the IP address.
    """
    return ".".join(str(addr >> 8 * i & 0xFF)
                    for i in reversed(range(4)))


def offset_mac(base, offset):
    """
    Add offset to a given MAC address.

    @param base: String representing a MAC address.
    @param offset: Offset to add to base (integer)
    @return: A string representing the offset MAC address.
    """
    return mac_int_to_str(mac_str_to_int(base) + offset)


def offset_ip(base, offset):
    """
    Add offset to a given IP address.

    @param base: String representing an IP address.
    @param offset: Offset to add to base (integer)
    @return: A string representing the offset IP address.
    """
    return ip_int_to_str(ip_str_to_int(base) + offset)


def verify_ip_address_ownership(ip, macs, timeout=10.0):
    """
    Use arping and the ARP cache to make sure a given IP address belongs to one
    of the given MAC addresses.

    @param ip: An IP address.
    @param macs: A list or tuple of MAC addresses.
    @return: True iff ip is assigned to a MAC address in macs.
    """
    # Compile a regex that matches the given IP address and any of the given
    # MAC addresses
    mac_regex = "|".join("(%s)" % mac for mac in macs)
    regex = re.compile(r"\b%s\b.*\b(%s)\b" % (ip, mac_regex), re.IGNORECASE)

    # Check the ARP cache
    o = commands.getoutput("/sbin/arp -n")
    if regex.search(o):
        return True

    # Get the name of the bridge device for arping
    o = commands.getoutput("/sbin/ip route get %s" % ip)
    dev = re.findall("dev\s+\S+", o, re.IGNORECASE)
    if not dev:
        return False
    dev = dev[0].split()[-1]

    # Send an ARP request
    o = commands.getoutput("/sbin/arping -f -c 3 -I %s %s" % (dev, ip))
    return bool(regex.search(o))


# Functions for working with the environment (a dict-like object)

def is_vm(obj):
    """
    Tests whether a given object is a VM object.

    @param obj: Python object (pretty much everything on python).
    """
    return obj.__class__.__name__ == "XenDomain"


def env_get_all_vms(env):
    """
    Return a list of all VM objects on a given environment.

    @param env: Dictionary with environment items.
    """
    vms = []
    for obj in env.values():
        if is_vm(obj):
            vms.append(obj)
    return vms


def env_get_vm(env, name):
    """
    Return a VM object by its name.

    @param name: VM name.
    """
    return env.get("vm__%s" % name)


def env_register_vm(env, name, vm):
    """
    Register a given VM in a given env.

    @param env: Environment where we will register the VM.
    @param name: VM name.
    @param vm: VM object.
    """
    env["vm__%s" % name] = vm


def env_unregister_vm(env, name):
    """
    Remove a given VM from a given env.

    @param env: Environment where we will un-register the VM.
    @param name: VM name.
    """
    del env["vm__%s" % name]


# Utility functions for dealing with external processes

def pid_exists(pid):
    """
    Return True if a given PID exists.

    @param pid: Process ID number.
    """
    try:
        os.kill(pid, 0)
        return True
    except:
        return False


def safe_kill(pid, signal):
    """
    Attempt to send a signal to a given process that may or may not exist.

    @param signal: Signal number.
    """
    try:
        os.kill(pid, signal)
        return True
    except:
        return False


def kill_process_tree(pid, sig=signal.SIGKILL):
    """Signal a process and all of its children.

    If the process does not exist -- return.

    @param pid: The pid of the process to signal.
    @param sig: The signal to send to the processes.
    """
    if not safe_kill(pid, signal.SIGSTOP):
        return
    children = commands.getoutput("ps --ppid=%d -o pid=" % pid).split()
    for child in children:
        kill_process_tree(int(child), sig)
    safe_kill(pid, sig)
    safe_kill(pid, signal.SIGCONT)


# The following are functions used for SSH, SCP and Telnet communication with
# guests.

def remote_login(command, password, prompt, linesep="\n", timeout=10):
    """
    Log into a remote host (guest) using SSH or Telnet. Run the given command
    using xen_spawn and provide answers to the questions asked. If timeout
    expires while waiting for output from the child (e.g. a password prompt
    or a shell prompt) -- fail.

    @brief: Log into a remote host (guest) using SSH or Telnet.

    @param command: The command to execute (e.g. "ssh root@localhost")
    @param password: The password to send in reply to a password prompt
    @param prompt: The shell prompt that indicates a successful login
    @param linesep: The line separator to send instead of "\\n"
            (sometimes "\\r\\n" is required)
    @param timeout: The maximal time duration (in seconds) to wait for each
            step of the login procedure (i.e. the "Are you sure" prompt, the
            password prompt, the shell prompt, etc)
    
    @return Return the xen_spawn object on success and None on failure.
    """
    sub = xen_subprocess.xen_shell_session(command,
                                           linesep=linesep,
                                           prompt=prompt)

    password_prompt_count = 0

    logging.debug("Trying to login with command '%s'" % command)
    
    while True: 
        (match, text) = sub.read_until_last_line_matches(
                [r"[Aa]re you sure", r"[Pp]assword:\s*$", r"^\s*[Ll]ogin:\s*$",
                 r"[Cc]onnection.*closed", r"[Cc]onnection.*refused", prompt],
                 timeout=timeout, internal_timeout=0.5)
        if match == 0:  # "Are you sure you want to continue connecting"
            logging.debug("Got 'Are you sure...'; sending 'yes'")
            sub.sendline("yes")
            continue
        elif match == 1:  # "password:"
            if password_prompt_count == 0:
                logging.debug("Got password prompt; sending '%s'" % password)
                sub.sendline(password)
                password_prompt_count += 1
                continue
            else:
                logging.debug("Got password prompt again")
                sub.close()
                return None
        elif match == 2:  # "login:"
            logging.debug("Got unexpected login prompt")
            sub.close()
            return None
        elif match == 3:  # "Connection closed"
            logging.debug("Got 'Connection closed'")
            sub.close()
            return None
        elif match == 4:  # "Connection refused"
            logging.debug("Got 'Connection refused'")
            sub.close()
            return None
        elif match == 5:  # prompt
            logging.debug("Got shell prompt -- logged in")
            return sub
        else:  # match == None
            logging.debug("Timeout elapsed or process terminated")
            sub.close()
            return None


def remote_scp(command, password, timeout=300, login_timeout=10):
    """
    Run the given command using xen_spawn and provide answers to the questions
    asked. If timeout expires while waiting for the transfer to complete ,
    fail. If login_timeout expires while waiting for output from the child
    (e.g. a password prompt), fail.

    @brief: Transfer files using SCP, given a command line.

    @param command: The command to execute
        (e.g. "scp -r foobar root@localhost:/tmp/").
    @param password: The password to send in reply to a password prompt.
    @param timeout: The time duration (in seconds) to wait for the transfer                                                                                                                  
        to complete.
    @param login_timeout: The maximal time duration (in seconds) to wait for
        each step of the login procedure (i.e. the "Are you sure" prompt or the
        password prompt)

    @return: True if the transfer succeeds and False on failure.
    """
    sub = xen_subprocess.xen_expect(command)

    password_prompt_count = 0
    _timeout = login_timeout

    logging.debug("Trying to login...")

    while True:
        (match, text) = sub.read_until_last_line_matches(
                [r"[Aa]re you sure", r"[Pp]assword:\s*$", r"lost connection"],
                timeout=_timeout, internal_timeout=0.5)
        if match == 0:  # "Are you sure you want to continue connecting"
            logging.debug("Got 'Are you sure...'; sending 'yes'")
            sub.sendline("yes")
            continue
        elif match == 1:  # "password:"
            if password_prompt_count == 0:
                logging.debug("Got password prompt; sending '%s'" % password)
                sub.sendline(password)
                password_prompt_count += 1
                _timeout = timeout
                continue
            else:
                logging.debug("Got password prompt again")
                sub.close()
                return False
        elif match == 2:  # "lost connection"
            logging.debug("Got 'lost connection'")
            sub.close()
            return False
        else:  # match == None
            logging.debug("Timeout elapsed or process terminated")
            status = sub.get_status()
            sub.close()
            return status == 0


def scp_to_remote(host, port, username, password, local_path, remote_path,
                  timeout=300):
    """
    Copy files to a remote host (guest).

    @param host: Hostname or IP address
    @param username: Username (if required)
    @param password: Password (if required)
    @param local_path: Path on the local machine where we are copying from
    @param remote_path: Path on the remote machine where we are copying to
    @param timeout: Time in seconds that we will wait before giving up to
            copy the files.

    @return: True on success and False on failure.
    """
    command = ("scp -o UserKnownHostsFile=/dev/null "
               "-o PreferredAuthentications=password -r -P %s %s %s@%s:%s" %
               (port, local_path, username, host, remote_path))
    return remote_scp(command, password, timeout)


def scp_from_remote(host, port, username, password, remote_path, local_path,
                    timeout=300):
    """
    Copy files from a remote host (guest).

    @param host: Hostname or IP address
    @param username: Username (if required)
    @param password: Password (if required)
    @param local_path: Path on the local machine where we are copying from
    @param remote_path: Path on the remote machine where we are copying to
    @param timeout: Time in seconds that we will wait before giving up to copy
            the files.

    @return: True on success and False on failure.
    """
    command = ("scp -o UserKnownHostsFile=/dev/null "
               "-o PreferredAuthentications=password -r -P %s %s@%s:%s %s" %
               (port, username, host, remote_path, local_path))
    return remote_scp(command, password, timeout)


def ssh(host, port, username, password, prompt, linesep="\n", timeout=10):
    """
    Log into a remote host (guest) using SSH.

    @param host: Hostname or IP address
    @param username: Username (if required)
    @param password: Password (if required)
    @param prompt: Shell prompt (regular expression)
    @timeout: Time in seconds that we will wait before giving up on logging
            into the host.

    @return: xen_spawn object on success and None on failure.
    """
    command = ("ssh -o UserKnownHostsFile=/dev/null "
               "-o PreferredAuthentications=password -p %s %s@%s" %
               (port, username, host))
    return remote_login(command, password, prompt, linesep, timeout)


def telnet(host, port, username, password, prompt, linesep="\n", timeout=10):
    """
    Log into a remote host (guest) using Telnet.

    @param host: Hostname or IP address
    @param username: Username (if required)
    @param password: Password (if required)
    @param prompt: Shell prompt (regular expression)
    @timeout: Time in seconds that we will wait before giving up on logging
            into the host.

    @return: xen_spawn object on success and None on failure.
    """
    command = "telnet -l %s %s %s" % (username, host, port)
    return remote_login(command, password, prompt, linesep, timeout)


def netcat(host, port, username, password, prompt, linesep="\n", timeout=10):
    """
    Log into a remote host (guest) using Netcat.

    @param host: Hostname or IP address
    @param username: Username (if required)
    @param password: Password (if required)
    @param prompt: Shell prompt (regular expression)
    @timeout: Time in seconds that we will wait before giving up on logging
            into the host.

    @return: xen_spawn object on success and None on failure.
    """
    command = "nc %s %s" % (host, port)
    return remote_login(command, password, prompt, linesep, timeout)


# The following are miscellaneous utility functions.

def get_path(base_path, user_path):
    """
    Translate a user specified path to a real path.
    If user_path is relative, append it to base_path.
    If user_path is absolute, return it as is.

    @param base_path: The base path of relative user specified paths.
    @param user_path: The user specified path.
    """
    if os.path.isabs(user_path):
        return user_path
    else:
        return os.path.join(base_path, user_path)


def generate_random_string(length):
    """
    Return a random string using alphanumeric characters.

    @length: length of the string that will be generated.
    """
    r = random.SystemRandom()
    str = ""
    chars = string.letters + string.digits
    while length > 0:
        str += r.choice(chars)
        length -= 1
    return str


def format_str_for_message(str):
    """
    Format str so that it can be appended to a message.
    If str consists of one line, prefix it with a space.
    If str consists of multiple lines, prefix it with a newline.

    @param str: string that will be formatted.
    """
    lines = str.splitlines()
    num_lines = len(lines)
    str = "\n".join(lines)
    if num_lines == 0:
        return ""
    elif num_lines == 1:
        return " " + str
    else:
        return "\n" + str


def wait_for(func, timeout, first=0.0, step=1.0, text=None):
    """
    If func() evaluates to True before timeout expires, return the
    value of func(). Otherwise return None.

    @brief: Wait until func() evaluates to True.

    @param timeout: Timeout in seconds
    @param first: Time to sleep before first attempt
    @param steps: Time to sleep between attempts in seconds
    @param text: Text to print while waiting, for debug purposes
    """
    start_time = time.time()
    end_time = time.time() + timeout

    time.sleep(first)

    while time.time() < end_time:
        if text:
            logging.debug("%s (%f secs)" % (text, time.time() - start_time))

        output = func()
        if output:
            return output

        time.sleep(step)

    logging.debug("Timeout elapsed")
    return None

def get_hostip_by_if(eth):
    s, o = commands.getstatusoutput("ifconfig %s" % eth)
    if s == 0:
        ip = re.findall("inet addr:(\S*)", o)[0]
        return ip
    else: 
        raise error.TestError("Got error when extrace information of %s; \
                               Reason %s" % (eth, o) )

def get_hostname_twin(hostname):
    """ get the twin machine hostname"""
    l = re.split('[-.]',hostname)[:4]
    l[3] = (lambda x: (x % 2) and str(x+1) or str(x-1))(int(l[3]))
    
    return '-'.join(l) + ".englab.nay.redhat.com"

def resolve_ip(hostname):
    """ get the ip address of hostname"""
    try:
        ip = socket.gethostbyname(hostname)
    except IndexError:
        return None
    return ip

def case_value_substitution(param, prefix):
    """
    (1) if param has a key like 'prefix_$name' and its value is not "NONE",
        make sure param['$name'] = param['prefix_$name']
    (2) elif param has a key like 'prefix_$name' and its value is "NONE",
        make sure the key '$name' and its value is deleted from param
    """
    pattern_string = '^' + prefix + '([\w+]*)'
    for key in param.keys():
        pattern = re.compile(pattern_string)
        m = pattern.match(key)
        if m:
            real_key = pattern.sub(r'\1', key)
            if param[key] == "NONE" and param.has_key(real_key):
                logging.info('Remove key \'%s\' from param and its value %s' \
                              % (real_key, param[real_key]))
                param.pop(real_key)
            elif not param.has_key(real_key):
                pass
            else:
                param[real_key] = param[key]
