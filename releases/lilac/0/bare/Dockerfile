# EDX-PLATFORM multi-stage docker build

# Change release to build, by providing the EDX_RELEASE_REF build argument to
# your build command:
#
# $ docker build \
#     --build-arg EDX_RELEASE_REF="open-release/hawthorn.1" \
#     -t edxapp:hawthorn.1 \
#     .
ARG DOCKER_UID=1000
ARG DOCKER_GID=1000
ARG EDX_RELEASE_REF=release-2021-09-30-16.02
ARG EDXAPP_STATIC_ROOT=/edx/app/edxapp/staticfiles
# Build nginx image form https://github.com/openfun/openshift-docker
#ARG NGINX_IMAGE_NAME=fundocker/openshift-nginx
ARG NGINX_IMAGE_NAME=nnlbebu/bb-edx-nginx
ARG NGINX_IMAGE_TAG=1.21.5

# === BASE ===
FROM ubuntu:focal as base

# Configure locales & timezone
RUN apt-get update &&\
    # Global requirements
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    curl \
    git \
    git-core \
    language-pack-en \
    libfreetype6-dev \
    libmysqlclient-dev \
    libssl-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libxslt1-dev \
    swig \
    # OpenedX requirements
    gettext \
    gfortran \
    graphviz \
    graphviz-dev \
    libffi-dev \
    libgeos-dev \
    libgraphviz-dev \
    libjpeg8-dev \
    liblapack-dev \
    libpng-dev \
    libsqlite3-dev \
    locales \
    lynx \
    ntp \
    pkg-config \
    python3-dev \
    python3-venv \
    rdfind \
    apt-transport-https \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

#RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
#    locale-gen
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# === DOWNLOAD ===
FROM base as downloads

WORKDIR /downloads

# Install curl
#RUN apt-get update &&\
#    apt-get install -y curl

# Download pip installer for python 3.8
RUN curl -sSL https://bootstrap.pypa.io/get-pip.py -o get-pip.py

# Download edxapp release
# Get default EDX_RELEASE_REF value (defined on top)
ARG EDX_RELEASE_REF
RUN curl -sLo edxapp.tgz https://github.com/edx/edx-platform/archive/$EDX_RELEASE_REF.tar.gz && \
    tar xzf edxapp.tgz

# === EDXAPP ===
FROM base as edxapp

# Install apt https support (required to use node sources repository)
#RUN apt-get update &&\
#    apt-get upgrade -y &&\
#    apt-get install -y apt-transport-https gnupg

# Add a recent release of nodejs to apt sources (ubuntu package for precise is
# broken)
RUN echo "deb https://deb.nodesource.com/node_12.x focal main" \
	> /etc/apt/sources.list.d/nodesource.list && \
    curl -fsSL 'https://deb.nodesource.com/gpgkey/nodesource.gpg.key' | apt-key add -

# Install base system dependencies
RUN apt-get update &&\
    apt-get install -y nodejs &&\
    rm -rf /var/lib/apt/lists/*

WORKDIR /edx/app/edxapp/edx-platform

# Get default EDX_RELEASE_REF value (defined on top)
ARG EDX_RELEASE_REF
COPY --from=downloads /downloads/edx-platform-* .

# We copy default configuration files to "/config" and we point to them via
# symlinks. That allows to easily override default configurations by mounting a
# docker volume.
#COPY ./config /config
#RUN ln -sf /config/lms /edx/app/edxapp/edx-platform/lms/envs/fun && \
#    ln -sf /config/cms /edx/app/edxapp/edx-platform/cms/envs/fun
#RUN ln -sf /config/lms /edx/app/edxapp/edx-platform/lms/envs && \
#    ln -sf /config/cms /edx/app/edxapp/edx-platform/cms/envs

# Add node_modules/.bin to the PATH so that paver-related commands can execute
# node scripts
#ENV PATH="/edx/app/edxapp/edx-platform/node_modules/.bin:${PATH}"

# === BUILDER ===
FROM edxapp as builder

WORKDIR /builder

# Install builder system dependencies
#RUN apt-get update && \
#    apt-get upgrade -y && \
#    apt-get install -y build-essential gettext git graphviz-dev libffi-dev libfreetype6-dev libgeos-dev libjpeg8-dev liblapack-dev libmysqlclient-dev libpng-dev libsqlite3-dev libxml2-dev libxmlsec1-dev lynx python3-dev ntp pkg-config rdfind && \
#    rm -rf /var/lib/apt/lists/*

# Install the latest pip release
COPY --from=downloads /downloads/get-pip.py ./get-pip.py
RUN python3.8 get-pip.py

WORKDIR /edx/app/edxapp/edx-platform/

# Patches
#COPY patches/* /tmp/

# Patches pre-install
# Patch requirements to install py2neo==3.1.2 from github as this version has been removed from pypi.org
#RUN patch -p1 < /tmp/edx-platform_master.0-bare_requirements-py2neo.patch

# Install python dependencies
RUN pip install -r requirements/pip.txt
RUN pip install -r requirements/edx/base.txt
RUN pip install -r requirements/edx/development.txt
RUN pip install gunicorn==20.1.0

# Install Javascript requirements
RUN npm set progress=false && npm install

# Update assets skipping collectstatic (it should be done during deployment)
#RUN paver update_assets --settings production --skip-collect
RUN NO_PREREQ_INSTALL=1 paver update_assets --settings=production --skip-collect
    #paver update_assets --settings=fun.docker_build_production --skip-collect
    

# === STATIC LINKS COLLECTOR ===
FROM builder as links_collector

ARG EDXAPP_STATIC_ROOT

#RUN python manage.py lms collectstatic --link --noinput --settings=fun.docker_run && \
#    python manage.py cms collectstatic --link --noinput --settings=fun.docker_run
RUN python manage.py lms collectstatic --link --noinput --settings production && \
    python manage.py cms collectstatic --link --noinput --settings production

# Replace duplicated file by a symlink to decrease the overall size of the
# final image
RUN rdfind -makesymlinks true -followsymlinks true ${EDXAPP_STATIC_ROOT}

# === STATIC FILES COLLECTOR ===
FROM builder as files_collector

ARG EDXAPP_STATIC_ROOT

#RUN python manage.py lms collectstatic --noinput --settings=fun.docker_run && \
#    python manage.py cms collectstatic --noinput --settings=fun.docker_run
RUN python manage.py lms collectstatic --noinput --settings production && \
    python manage.py cms collectstatic --noinput --settings roduction

# Replace duplicated file by a symlink to decrease the overall size of the
# final image
RUN rdfind -makesymlinks true ${EDXAPP_STATIC_ROOT}

# === DEVELOPMENT ===
FROM builder as development

ARG DOCKER_UID
ARG DOCKER_GID
ARG EDX_RELEASE_REF

# Install system dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
      libsqlite3-dev \
      mongodb && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd --gid ${DOCKER_GID} edx || \
    echo "Group with ID ${DOCKER_GID} already exists." && \
    useradd \
      --create-home \
      --home-dir /home/edx \
      --uid ${DOCKER_UID} \
      --gid ${DOCKER_GID} \
      edx || \
    echo "Skip user creation (user with ID ${DOCKER_UID} already exists?)"

# To prevent permission issues related to the non-priviledged user running in
# development, we will install development dependencies in a python virtual
# environment belonging to that user
RUN pip install virtualenv

# Create the virtualenv directory where we will install python development
# dependencies
RUN mkdir -p /edx/app/edxapp/venv && \
    chown -R ${DOCKER_UID}:${DOCKER_GID} /edx/app/edxapp/venv

# Change edxapp directory owner to allow the development image docker user to
# perform installations from edxapp sources (yeah, I know...)
RUN chown -R ${DOCKER_UID}:${DOCKER_GID} /edx/app/edxapp

# Copy the entrypoint that will activate the virtualenv
COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh

# Switch to an un-privileged user matching the host user to prevent permission
# issues with volumes (host folders)
USER ${DOCKER_UID}:${DOCKER_GID}

# Create the virtualenv with a non-priviledged user
RUN virtualenv -p python3.8 --system-site-packages /edx/app/edxapp/venv

# Install development dependencies in a virtualenv
RUN bash -c "source /edx/app/edxapp/venv/bin/activate && \
    pip install --no-cache-dir -r requirements/edx/testing.txt && \
    pip install --no-cache-dir -r requirements/edx/development.txt"

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]


# === PRODUCTION ===
FROM edxapp as production

ARG EDXAPP_STATIC_ROOT

# Install runner system dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
    libgeos-dev \
    libmysqlclient20 \
    libxml2 \
    libxmlsec1-dev \
    lynx \
    tzdata && \
    rm -rf /var/lib/apt/lists/*

# Copy installed dependencies
COPY --from=builder /usr/local /usr/local

# Copy modified sources (sic!)
COPY --from=builder /edx/app/edxapp/edx-platform  /edx/app/edxapp/edx-platform

# Copy static files
COPY --from=links_collector ${EDXAPP_STATIC_ROOT} ${EDXAPP_STATIC_ROOT}

# Now that dependencies are installed and configuration has been set, the above
# statements will run with a un-privileged user.
USER 10000

# To start the CMS, inject the SERVICE_VARIANT=cms environment variable
# (defaults to "lms")
ENV SERVICE_VARIANT=lms

# Gunicorn configuration
#
# We want to be able to easily increase gunicorn if needed
ENV GUNICORN_TIMEOUT 300

# In docker we must increase the number of workers and threads created
# by gunicorn.
# This blogpost explains why and how to do that https://pythonspeed.com/articles/gunicorn-in-docker/
ENV GUNICORN_WORKERS 3
ENV GUNICORN_THREADS 6

# Use Gunicorn in production as web server
#CMD DJANGO_SETTINGS_MODULE=${SERVICE_VARIANT}.envs.fun.docker_run \
CMD DJANGO_SETTINGS_MODULE=${SERVICE_VARIANT}.envs.docker_run \
    gunicorn \
      --name=${SERVICE_VARIANT} \
      --bind=0.0.0.0:8000 \
      --max-requests=1000 \
      --timeout=${GUNICORN_TIMEOUT} \
      --workers=${GUNICORN_WORKERS} \
      --threads=${GUNICORN_THREADS} \
      ${SERVICE_VARIANT}.wsgi:application

# === NGINX ===
FROM ${NGINX_IMAGE_NAME}:${NGINX_IMAGE_TAG} as nginx

ARG EDXAPP_STATIC_ROOT

RUN mkdir -p ${EDXAPP_STATIC_ROOT}

COPY --from=files_collector ${EDXAPP_STATIC_ROOT} ${EDXAPP_STATIC_ROOT}
