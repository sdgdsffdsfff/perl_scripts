import logging
from autotest_lib.client.common_lib import error
import xm, xen_test_utils

def run_vcpu_list(test, params, env):
    """
    xm vcpu-list
    1) Get vcpus from host
    2) Get cpus from domainU
    3) Number of vcpus should equal to cpus

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    # Get vcpus from "xm vcpu-list" in host
    vcpus_xm = len(xm.get_VcpuInfo(vm.name))

    cpus_domainU = xen_test_utils.get_domainU_cpus(vm)

    if vcpus_xm != cpus_domainU:
        raise error.TestFail("Vcpus(%s) in vcpu-list differ from cpus(%s)"
                             " in guest" % (vcpus_xm, cpus_domainU))

