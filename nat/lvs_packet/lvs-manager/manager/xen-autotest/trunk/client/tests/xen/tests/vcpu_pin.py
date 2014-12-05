import logging, random, time
from autotest_lib.client.common_lib import error
import xm, xen_test_utils, xen_subprocess

def run_vcpu_pin(test, params, env):
    """
    xm vcpu-pin 
    1) Pin one cpu; check_vcpu_pin(CPU Affinity is "n") 
    2) Pin a range of cpus; check_vcpu_pin("m-n")
    3) If pin all cpus; check_vcpu_pin("any cpu")
    4) Finally,pin every vcpu with all cpus

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    cpus_host = xm.smp_ConcurrencyLevel()
    if cpus_host <= 1:
        raise error.TestNAError("This machine does not have more than one "
                                "physical or logical cpu.  The vcpu-pin "
                                "test cannot be run!")

    vcpus_boot = int(params.get("vcpus"))

    try:
        # Pin to one cpu
        vcpu_to_pin = random.randint(0, vcpus_boot-1)
        cpus_to_pin = random.randint(0, cpus_host-1)
        do_vcpu_pin(vm, vcpu_to_pin, cpus_to_pin)    
        check_vcpu_pin(vm, vcpu_to_pin, cpus_to_pin, False)

        # Pin to several cpus,like 0-2
        vcpu_to_pin = random.randint(0, vcpus_boot-1)
        cpus_toplimit = random.randint(1, cpus_host-1)
        cpus_to_pin = "0-%s" % cpus_toplimit
        do_vcpu_pin(vm, vcpu_to_pin, cpus_to_pin)

        if cpus_toplimit == cpus_host-1:
            check_vcpu_pin(vm, vcpu_to_pin, cpus_to_pin, True)
        else:
            check_vcpu_pin(vm, vcpu_to_pin, cpus_to_pin, False)
    finally:
        for vcpu in range(vcpus_boot):
            do_vcpu_pin(vm, vcpu, "0-%s" % (cpus_host-1))


def do_vcpu_pin(vm, vcpu_to_pin, cpus_to_pin):
    """
    vcpu is for guest
    cpus is for host
    """
    xm_cmd = "xm vcpu-pin %s %s %s" % (vm.name, vcpu_to_pin, cpus_to_pin)

    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,
                                           "(xm vcpu-pin) ", timeout=60)

    if status is None:
        raise error.TestFail("Timeout when pin vcpu with command: %s\n"
                             "output: %s" % (xm_cmd, output))
    elif status != 0:
        raise error.TestFail("Error when pin vcpu with command: %s\n" 
                             "output: %s" % (xm_cmd, output))


def check_vcpu_pin(vm, vcpu, cpus, pin_all):
    """
    xm vcpu-list domain
    vcpus: {VCPU:(CPU, State, CPU Affinity), ...}
    """
    vcpus = xm.get_VcpuInfo(vm.name)
    
    if not pin_all:
        if not (vcpus[vcpu][2] == str(cpus)):
            raise error.TestFail("Pin vcpu failed,CPU Affinity is not %s"
                                 % cpus)
    else:
        if not (vcpus[vcpu][2] == "any cpu"):
            raise error.TestFail("Pin to all vcpu failed,CPU Affinity is not"
                                 " \"any cpu\"") 

