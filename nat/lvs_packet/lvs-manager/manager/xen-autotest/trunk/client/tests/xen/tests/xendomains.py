import os
import time
import logging
import domain
import xm, xen_utils, xen_test_utils, xen_subprocess
from autotest_lib.client.common_lib import error

def run_xendomains(test, params, env):
    name = params.get("main_vm")
    vm = xen_utils.env_get_vm(env, name)

    # generate the config file
    config = vm.make_config(name, params, test.bindir, env, dry_run=True)
    str(config)

    cmdtmpl = "/etc/init.d/xendomains %s"

    def _rm_f(path):
        if os.path.exists(path):
            os.unlink(path)

    def _start():
        os.system(cmdtmpl % 'start')
        time.sleep(10)

    def _stop():
        os.system(cmdtmpl % 'stop')
        time.sleep(10)

    def xendomains_start():
        # setup the environment
        xm.destroy_DomU(name)
        _stop()
        os.system("sed -i '/^XENDOMAINS_AUTO/s:=.*$:=/etc/xen/auto:' /etc/sysconfig/xendomains")
        ln = "/etc/xen/auto/dom1.cfg"
        _rm_f(ln)
        os.symlink("/tmp/xm-test.conf", ln)

        _start()

        xen_test_utils.wait_for_login(vm)


    cmd = params['cmd']
    if cmd == 'start':
        xendomains_start()

    elif cmd == 'stop':
        # reuse the environment set up by the 'start' case
        os.system("sed -i '/^XENDOMAINS_SAVE/s:=.*$:=:' /etc/sysconfig/xendomains")

        _stop()

        if xm.is_DomainRunning(name):
            raise error.TestFail("xendomains stop failed, domain is still running")

    elif cmd == 'save':
        xendomains_start()

        os.system("sed -i '/^XENDOMAINS_SAVE/s:=.*$:=/var/lib/xen/save:' /etc/sysconfig/xendomains")

        _stop()

        if not os.path.exists("/var/lib/xen/save/"+name):
            raise error.TestFail("xendomains save failed, saved file not found")

    elif cmd == 'restore':
        os.system("sed -i '/^XENDOMAINS_RESTORE/s:=.*$:=true:' /etc/sysconfig/xendomains")

        _start()

        xen_test_utils.wait_for_login(vm)

    elif cmd == 'restart':
        xendomains_start()

        os.system(cmdtmpl % 'restart')
        time.sleep(20)

        xen_test_utils.wait_for_login(vm)

    elif cmd == 'status':
        import subprocess

        _stop()
        out = subprocess.Popen(["/etc/init.d/xendomains", "status"], stdout=subprocess.PIPE).communicate()[0]

        assert out.find('FAILED') >= 0

        _start()
        out = subprocess.Popen(["/etc/init.d/xendomains", "status"], stdout=subprocess.PIPE).communicate()[0]

        assert out.find('OK') >= 0

    elif cmd == 'restore_fail':

        def create_invalid():
            f = open("/var/lib/xen/save/invalid", "w")
            f.truncate(50 * 1024 * 1024)
            f.close()

        # clean up
        xm.destroy_DomU(name)
        _rm_f("/etc/xen/auto/dom1.cfg")
        _stop()

        # setup config
        os.system("sed -i '/^XENDOMAINS_SAVE/s:=.*$:=/var/lib/xen/save:' /etc/sysconfig/xendomains")
        os.system("sed -i '/^XENDOMAINS_RESTORE/s:=.*$:=true:' /etc/sysconfig/xendomains")

        # create the invalid image
        create_invalid()

        # test rename
        os.system("sed -i '/^XENDOMAINS_RESTOREFAILTYPE/s:=.*$:=rename:' /etc/sysconfig/xendomains")

        _start()

        if not os.path.exists("/var/lib/xen/save/.invalid"):
            raise error.TestFail("xendomains rename failed, file not found")

        # test delete
        _stop()
        os.unlink("/var/lib/xen/save/.invalid")

        create_invalid()

        os.system("sed -i '/^XENDOMAINS_RESTOREFAILTYPE/s:=.*$:=delete:' /etc/sysconfig/xendomains")

        _start()

        if os.path.exists("/var/lib/xen/save/invalid"):
            raise error.TestFail("xendomains delete failed, file not deleted")

        # test none
        _stop()

        create_invalid()

        os.system("sed -i '/^XENDOMAINS_RESTOREFAILTYPE/s:=.*$:=none:' /etc/sysconfig/xendomains")

        _start()

        if not os.path.exists("/var/lib/xen/save/invalid"):
            raise error.TestFail("xendomains none failed, file not found")
