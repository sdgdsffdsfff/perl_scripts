import logging, random, time
from autotest_lib.client.common_lib import error
import xm, xen_test_utils, xen_subprocess

def run_vcpu_set(test, params, env):
    """
    xm vcpu-set(only PV)
    1) Set vcpus for domainU
    2) Get plugged vcpus from host
    3) Get cpus from domainU
    4) Number of plugged vcpus should equal to cpus
    5) Plug all vcpus

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    vcpus_boot = int(params.get("vcpus", 1))
    try:
        # Plug part of all vcpus
        vcpus_to_plug = random.randint(0, vcpus_boot)
        logging.info("Set active vcpu to number %s" % vcpus_to_plug)
        vcpu_set(vm, vcpus_to_plug)

        # Wait for the change to become active
        time.sleep(1)

        vcpus_plugged = get_vcpus_plugged(vm)
        cpus_domainU = xen_test_utils.get_domainU_cpus(vm)

        # When vcpus_to_plug=0, make sure at least one cpu available
        if vcpus_to_plug == 0:
            if not (vcpus_plugged == 1 and cpus_domainU == 1):
                raise error.TestFail("Set active vcpus to number 0 failed.")
        elif not (vcpus_plugged == vcpus_to_plug and 
                  cpus_domainU == vcpus_to_plug):
            raise error.TestFail("Set active vcpus to number %s failed."
                                 % vcpus_to_plug)
    finally:
        # Replug all vcpus
        logging.info("Set all(%s) vcpus to be active."% vcpus_boot)
        vcpu_set(vm, vcpus_boot)


def vcpu_set(vm, vcpus_to_plug):
    xm_cmd = "xm vcpu-set %s %s" % (vm.name, vcpus_to_plug)

    status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,
                                           "(xm vcpu-set) ", timeout=60)

    if status is None:
        raise error.TestFail("Timeout when set vcpu with command: %s\n"
                             "output: %s" % (xm_cmd, output))
    elif status != 0:
        raise error.TestFail("Error when set vcpu with command: %s\n"
                             "output: %s" % (xm_cmd, output))


def get_vcpus_plugged(vm):
    """
    vcpus stores [vcpu:cpu] pair,like: {0: 0, 1: None}
    Value None means unplugged vcpu
    """
    vcpus = xm.get_VcpuInfo(vm.name)

    values = vcpus.values()

    vcpus_plugged = 0
    for value in values:
        logging.debug("vcpus value is %s" % value)
        if not(value[0] == "-" and value[1][2] == "p"):
            vcpus_plugged += 1 

    return vcpus_plugged
