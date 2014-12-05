import logging, re, random
from autotest_lib.client.common_lib import error
import xm, xen_test_utils, xen_subprocess

def run_sched_credit(test, params, env):
    """
    xm sched-credit -d domain -w weight -c cap
    1) Got a living vm
    2) List sched-credit parameters for vm
    3) Modify weight for vm and check, weight range(1, 65535)
    4) Modify cap for vm and check, cap range(0, vcpus*100)

    @param test: Xen test object
    @param params: Dictionary with the test parameters
    @param env: Dictionary with test environment.
    """
    vm = xen_test_utils.get_living_vm(env, params.get("main_vm"))

    def get_sched_credit_params(domain):
        xm_cmd = "xm sched-credit -d %s" % domain
        status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                               "(xm sched-credit) ", timeout=60)
        if status is None:
            raise error.TestFail("Timeout when get sched-credit params with command:"
                                 "%s\n output:%s" % (xm_cmd, output))
        elif status != 0:
            raise error.TestFail("Error when get sched-credit params with command:"
                                 "%s\n output:%s" % (xm_cmd, output))
        match = re.findall("(\d+)", output) 
        cap = int(match[0])
        weight = int(match[1])
        return (cap, weight)


    def set_sched_credit_weight(domain, weight):
        xm_cmd = "xm sched-credit -d %s -w %s" % (domain, weight)
        status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                               "(xm sched-credit) ", timeout=60)
        if status is None:
            raise error.TestFail("Timeout when set sched-credit weight with command:"
                                 "%s\n output:%s" % (xm_cmd, output))
        elif status != 0:
            if weight in range(1, 65535):
                raise error.TestFail("Error when set sched-credit weight with command:"
                                     "%s\n output:%s" % (xm_cmd, output))


    def set_sched_credit_cap(domain, cap, cap_upper_limit=100):
        xm_cmd = "xm sched-credit -d %s -c %s" % (domain, cap)
        status, output = xen_subprocess.run_fg(xm_cmd, logging.debug,\
                                               "(xm sched-credit) ", timeout=60)
        if status is None:
            raise error.TestFail("Timeout when set sched-credit cap with command:"
                                 "%s\n output:%s" % (xm_cmd, output))
        elif status != 0:
            if cap in range(0, cap_upper_limit):
                raise error.TestFail("Error when set sched-credit cap with command:"
                                     "%s\n output:%s" % (xm_cmd, output))
 

    cap, weight = get_sched_credit_params(vm.name)
    if not (cap == 0 and weight == 256):
        raise error.TestFail("Default (cap, weight) is not (0, 256),got (%s, %s)"
                             % (cap, weight))
    try:
        # Reset weight
        weight_new = random.randint(1, 65535)
        set_sched_credit_weight(vm.name, weight_new)
        cap_current, weight_current= get_sched_credit_params(vm.name)
        if weight_current != weight_new:
            raise error.TestFail("Weight set error, intent is %s, actual is %s"
                                 % (weight_new, weight_current))
        logging.info("Set weight to %s" % weight_current)

        # Weight boundary test (1, 65535)
        set_sched_credit_weight(vm.name, 0)
        set_sched_credit_weight(vm.name, 65536)

        # Reset cap
        vcpus = int(params.get("vcpus", 4))
        cap_upper_limit = vcpus*100
        cap_new = random.randint(0, cap_upper_limit)	
        set_sched_credit_cap(vm.get_id(), cap_new, cap_upper_limit)
        cap_current, weight_current= get_sched_credit_params(vm.name)
        cap_current, weight_current= get_sched_credit_params(vm.name)
        if cap_current != cap_new:
            raise error.TestFail("Cap set error, intent is %s, actual is %s"
                                 % (cap_new, cap_current))
        logging.info("Set cap to %s" % cap_current)

        # Cap boundary test (0,vcpus*100)
        set_sched_credit_cap(vm.get_id(), -1, cap_upper_limit)
        set_sched_credit_cap(vm.get_id(), cap_upper_limit+1, cap_upper_limit)

    finally:
       set_sched_credit_weight(vm.get_id(), 256)
       set_sched_credit_cap(vm.name, 0)

