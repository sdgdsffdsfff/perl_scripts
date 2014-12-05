import os, logging, re, random, math, time, socket
from autotest_lib.client.common_lib import error
import xen_utils, xen_test_utils, xm, xen_subprocess


def run_ping_pong_migration(test, params, env):
    """
    (1) Get src and dst host machine ip
    (2) Log into the dst host to mount shared storage
    (1) Get a living vm for test
    (2) Get 
    (2) Log into the guest and run a command
    (3) Start a background process within the guest
    (4) Do the migration
    (5) After migration, log into the guest again and check if 
        the background process is still running
    """
    # local function 
    def get_host_session(host, params, timeout=10):
        """ get a session to a host """
        username = params.get("host_username", "")
        password = params.get("host_password", "")
        prompt = params.get("host_shell_prompt", "[\#\$]")
        linesep = eval("'%s'" % params.get("host_shell_linesep", r"\n"))
        port = params.get("host_shell_port")

        if not port:
            logging.debug("Port unavailable")
            return None
        session = xen_utils.ssh(host, port, username, password, prompt, 
                                linesep, timeout)
        if session:
            session.set_status_test_command(params.get("host_status_test_"
                                                            "command", "echo $?"))
        return session


    def do_remote_mount(session, nfs_path, mount_point):
        """ mount nfs_path to mount_point via session """
        # Make sure session is active
        if not session.is_responsive():
            raise error.TestError("Session is not responsive \
                                   when try to do mount")
        logging.debug("mount_point:%s" % mount_point)
        # Make sure mount_point exist
          
        s,o = session.get_command_status_output(command="ls %s" % mount_point) 
        if s != 0 and s != None:
            logging.debug("mount point doesn't exist, create it; Reason(%s,%s)" % (s,o))
            s, o = session.get_command_status_output("mkdir -p %s" % mount_point)
            if s != 0:
                raise error.TestError("Couldn't make dir for %s via session;\
                                       Reason %s" % (mount_point, o))
        elif s == None:
            raise error.TestError("Timeout when determine if mount point existed")
        else:
            logging.debug("mount point already existed")
            # eliminate any symbolic link in the path
            s,o = session.get_command_status_output("readlink " + mount_point)
            if s == 0:
                logging.debug("symbolic link dereferenced")
                mount_point = o

        # Mount nfs_path to mount_point
        s, o = session.get_command_status_output("mount | grep %s | grep %s" \
                                                  % (mount_point, nfs_path))
        if s != 0 and s != None:
            logging.debug("Remote image dir is not mounted, going to mount it")
            mnt_cmd = "mount %s %s" % (nfs_path, mount_point)
            s, o = session.get_command_status_output(mnt_cmd)
            if s != 0:
                raise error.TestError("Failed to mount %s on %s via session; \
                                 Reason: %s" % (nfs_path, mount_point, o))
        elif s == None:
            raise error.TestError("Timeout when determine if remote image is \
                                   already mounted")
        else:
            logging.debug("Image dir already mounted")
        
        # Check if mounting is successfully
        s, o = session.get_command_status_output("mount | grep %s | grep %s" \
                                                  % (mount_point, nfs_path))
        if s != 0:
            raise error.TestError("Image dir mounted failed")

    def destroy_remote_vm(dst_host_session, vm_name):
        if not dst_host_session.is_responsive():
            raise error.TestError("Session is not responsive")
        chk_cmd = "xm li %s" % vm_name
        s, o = dst_host_session.get_command_status_output(chk_cmd)
        if s == 0:
            destroy_cmd = "xm destroy %s" % vm_name
            s, o = dst_host_session.get_command_status_output(destroy_cmd)
            if s != 0:
                raise error.TestFail("Destroy same name vm in remote machine"
                                     "failed, Reason %s" % o)

    def chk_remote_alive(dst_host_session, vm_name):
        if not dst_host_session.is_responsive():
            raise error.TestError("Session is not responsive")
        chk_cmd = "xm li %s" % vm_name
        s, o = dst_host_session.get_command_status_output(chk_cmd)
        if s != 0:
            raise error.TestFail("VM %s doesn't exist in remote machine \
                                  after migration; Reason %s" % (vm_name, o)) 

    def vm_migrate_back(session, vm_name, src_host):
        """ migrate vm_name back to src_host via session """
        if not session.is_responsive():
            raise error.TestError("Session is not responsive")
        mig_cmd = "xm migrate -l %s %s" % (vm_name, src_host)
        s, o = session.get_command_status_output(mig_cmd)
        if s != 0:
            raise error.TestFail("Failed to migrate %s back to %s; Reason %s" %
                                  (vm_name, src_host, o))

    # Src
    src_hostname = socket.gethostname()
    src_host = xen_utils.get_hostip_by_if("eth0")
    if src_host == None:
        raise error.TestError("Couldn't get ip address of localhost %s" 
                                 % src_hostname)
    logging.debug("Got src_host:%s" % src_host)

    # Dst
    if params.has_key("dst_host"): 
        dst_host = params.get("dst_host")
    else:
        dst_hostname = xen_utils.get_hostname_twin(src_hostname)
        dst_host = xen_utils.resolve_ip(dst_hostname)
        if dst_host == None:
            raise error.TestError("Couldn't get ip address of twin machine %s"
                                                               % dst_hostname)
    logging.debug("Got dst_host:%s" % dst_host)

    # Get session to dst_host
    dst_host_session = get_host_session(dst_host, params)
    if dst_host_session == None:
        raise error.TestError("Couldn't get session to host %s" % dst_host)

    # export_path = local ip + path to images
    export_path = src_host + ':' + os.environ['IMAGE_DIR']

    mount_point = os.path.join(test.bindir,"images")

    #try:
    do_remote_mount(dst_host_session, export_path, mount_point)
    #except:
    #    logging.debug("close dst_host_session")
     #   dst_host_session.close()

    
    if not dst_host_session.is_responsive():
        logging.debug("dst_host_session not alive")

    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    vm_name = vm.get_name()
    
    # Destroy the same name vm running in dst_host
    destroy_remote_vm(dst_host_session, vm_name)

    mig_timeout = float(params.get("mig_timeout", "3600"))
    migration_iterations = int(params.get("pq_migration_iterations", 1))

    # From here we do migration testing for a fixed times
    for i in range(migration_iterations):
        logging.info("The %d/%d migration" % (int(i)+1, migration_iterations))
        # Make sure the vm is still alive on the host
        if not vm.is_running():
            raise error.TestFail("VM not is not alive on src host for the \
                                  %d migration" % i)

        session = xen_test_utils.wait_for_login(vm)
    
        if not dst_host_session.is_responsive():
            logging.debug("dst_host_session not alive")
    
        # Get the output of migration_test_command
        test_command = params.get("migration_test_command")
        if not test_command:
            raise error.TestError("No migration_test_command set for this test")

        reference_output = session.get_command_output(test_command)

        # Start some process in the background (and leave the session open)
        background_command = params.get("migration_bg_command", "")
        session.sendline(background_command)
        time.sleep(5)

        # Start another session with the guest and make sure the background
        # process is running
        session2 = xen_test_utils.wait_for_login(vm)

        try:
            check_command = params.get("migration_bg_check_command", "")
            if session2.get_command_status(check_command, timeout=30) != 0:
                raise error.TestError("Could not start background process '%s'" %
                                  background_command)
            session2.close()

            # Migrate the VM
            # dest_vm is just the instance of original vm, althrough it 
            # has been migrated to remote
            dest_vm = xen_test_utils.migrate(vm, dst_host, mig_timeout)

            if not dst_host_session.is_responsive():
                logging.debug("dst_host_session not alive before migration")
            # Check the vm is there on the remote host
            chk_remote_alive(dst_host_session, vm_name)

            if not dst_host_session.is_responsive():
                logging.debug("dst_host_session not alive after migration")
            # Log into the guest again
            logging.info("Logging into guest after migration...")
            session2 = xen_test_utils.wait_for_login(dest_vm)
            if not session2:
               raise error.TestFail("Could not log into guest after migration")
            logging.info("Logged in after migration")

            # Make sure the background process is still running
            if session2.get_command_status(check_command, timeout=30) != 0:
                raise error.TestFail("Could not find running background process "
                                     "after migration: '%s'" % background_command)

            # Get the output of migration_test_command
            output = session2.get_command_output(test_command)

            # Compare output to reference output
            if output != reference_output:
                logging.info("Command output before migration differs from "
                             "command output after migration")
                logging.info("Command: %s" % test_command)
                logging.info("Output before:" +
                             xen_utils.format_str_for_message(reference_output))
                logging.info("Output after:" +
                             xen_utils.format_str_for_message(output))
                raise error.TestFail("Command '%s' produced different output "
                                     "before and after migration" % test_command)

        finally:
            # Kill the background process
            if session2 and session2.is_alive():
                session2.get_command_output(params.get("migration_bg_kill_command",
                                                   ""))
            if session and session.is_alive():
                session.get_command_output(params.get("migration_bg_kill_command",
                                                   ""))
        
        session2.close()
        session.close()

        # Migrate VM back to src_host
        vm_migrate_back(dst_host_session, vm_name, src_host)

    logging.debug("All migration finished")
