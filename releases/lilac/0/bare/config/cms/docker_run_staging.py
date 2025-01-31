# This file includes overrides to build the `staging` environment for the CMS starting from the
# settings of the `production` environment

from docker_run_production import *
#from lms.envs.fun.utils import Configuration
from lms.envs.utils import Configuration

# Load custom configuration parameters from yaml files
config = Configuration(os.path.dirname(__file__))

LOGGING["handlers"]["sentry"]["environment"] = "staging"

EMAIL_BACKEND = config(
    "EMAIL_BACKEND", default="django.core.mail.backends.console.EmailBackend"
)
