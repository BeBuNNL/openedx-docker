# This file includes overrides to build the `development` environment for the CMS, starting from
# the settings of the `production` environment

from docker_run_production import *
#from lms.envs.fun.utils import Configuration
from lms.envs.utils import Configuration

# Load custom configuration parameters from yaml files
config = Configuration(os.path.dirname(__file__))

if "sentry" in LOGGING.get("handlers"):
    LOGGING["handlers"]["sentry"]["environment"] = "development"

DEBUG = True
REQUIRE_DEBUG = True

EMAIL_BACKEND = config(
    "EMAIL_BACKEND", default="django.core.mail.backends.console.EmailBackend"
)


PIPELINE_ENABLED = False
STATICFILES_STORAGE = "openedx.core.storage.DevelopmentStorage"

ALLOWED_HOSTS = ["*"]
