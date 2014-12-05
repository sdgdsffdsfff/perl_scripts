import sys, os, time, logging
from autotest_lib.client.bin import test
from autotest_lib.client.common_lib import error
import xen_utils, xen_preprocessing

class xen(test.test):
    """
    Suite of Xen virtualization functional tests.

    """
    version = 1
    def initialize(self):
        self.subtest_dir = os.path.join(self.bindir, 'tests')


    def run_once(self, params):
        # Report the parameters we've received and write them as keyvals
        logging.debug("Test parameters:")
        keys = params.keys()
        keys.sort()
        for key in keys:
            logging.debug("    %s = %s", key, params[key])
            self.write_test_keyval({key: params[key]})

        # Open the environment file
        env_filename = os.path.join(self.bindir, params.get("env", "env"))
        env = xen_utils.load_env(env_filename, {})
        logging.debug("Contents of environment: %s" % str(env))

        try:
            try:
                # Get the test routine corresponding to the specified test type
                t_type = params.get("type")
                # Verify if we have the correspondent source file for it
                module_path = os.path.join(self.subtest_dir, '%s.py' % t_type)
                if not os.path.isfile(module_path):
                    raise error.TestError("No %s.py test file found" % t_type)
                # Load the test module
                # (Xen test dir was appended to sys.path in the control file)
                __import__("tests.%s" % t_type)
                test_module = sys.modules["tests.%s" % t_type]
                # Preprocess
                xen_preprocessing.preprocess(self, params, env)
                xen_utils.dump_env(env, env_filename)
                # Run the test function
                run_func = getattr(test_module, "run_%s" % t_type)
                run_func(self, params, env)
                xen_utils.dump_env(env, env_filename)

            except Exception, e:
                logging.error("Test failed: %s", e)
                logging.debug("Postprocessing on error...")
                xen_preprocessing.postprocess_on_error(self, params, env)
                xen_utils.dump_env(env, env_filename)
                raise

        finally:
            # Postprocess
            xen_preprocessing.postprocess(self, params, env)
            logging.debug("Contents of environment: %s", str(env))
            xen_utils.dump_env(env, env_filename)
