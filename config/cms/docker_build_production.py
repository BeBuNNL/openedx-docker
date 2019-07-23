# This is a minimal settings file allowing us to run "update_assets"
# in the Dockerfile for the production image of the edxapp CMS

from lms.envs.fun.utils import Configuration
from path import Path as path

from ..common import *

# Load custom configuration parameters
config = Configuration()

DATABASES = {"default": {}}

XQUEUE_INTERFACE = {"url": None, "django_auth": None}

# We need to override STATIC_ROOT because for CMS, edX appends the value of
# "EDX_PLATFORM_REVISION" to it by default and we don't want to use this.
# We should use Django's ManifestStaticFilesStorage for this purpose.
STATIC_URL = "/static/studio/"
STATIC_ROOT = path("/edx/app/edxapp/staticfiles/studio")

# Allow setting a custom theme
DEFAULT_SITE_THEME = config("DEFAULT_SITE_THEME", default=None)
