# Open edX
# Docker containers CI
version: 2

# Templates
defaults: &defaults # We use the machine executor, i.e. a VM, not a container
  machine:
    # Cache docker layers so that we strongly speed up this job execution
    # This cache will be available to future jobs (although because jobs run
    # in parallel, CircleCI does not guarantee that a given job will see a
    # specific version of the cache. See documentation for details)
    docker_layer_caching: true

#  working_directory: ~/fun
  working_directory: ~/

build_steps: &build_steps
  steps:
    # Checkout openedx-docker sources
    - checkout

    # Login to DockerHub with encrypted credentials stored as secret
    # environment variables (set in CircleCI project settings) if the expected
    # environment variable is set; switch to anonymous mode otherwise.
    - run:
        name: Login to DockerHub
        command: >
          test -n "$DOCKER_USER" &&
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin ||
            echo "Docker Hub anonymous mode"

    # Skip release build & testing if changes are not targeting it
    - run:
        name: Check if changes are targeting the current release
        command: bin/ci checkpoint

    # Install a recent docker-compose release
    - run:
        name: Upgrade docker-compose
        command: |
          curl -L "https://github.com/docker/compose/releases/download/1.25.1/docker-compose-$(uname -s)-$(uname -m)" -o ~/docker-compose
          chmod +x ~/docker-compose
          sudo mv ~/docker-compose /usr/local/bin/docker-compose

    # Production image build
    - run:
        name: Build production image
        command: |
          source $(bin/ci activate_path)
          make build

    # Development image build. It uses the "development" Dockerfile target
    # file
    - run:
        name: Build development image
        command: |
          source $(bin/ci activate_path)
          make dev-build

    # Bootstrap
    - run:
        name: Bootstrap the CMS & LMS
        command: |
          source $(bin/ci activate_path)
          make tree
          make migrate
          make run

    # Check that the production build starts
    - run:
        name: Check production build
        command: |
          source $(bin/ci activate_path)
          make test-cms
          make test-lms

    # Check that the demo course can be imported
    - run:
        name: Import demonstration course
        command: |
          source $(bin/ci activate_path)
          make demo-course

# List openedx-docker jobs that will be integrated and executed in a workflow
jobs:
  # Quality jobs

  # Check that the git history is clean and complies with our expectations
  lint-git:
    docker:
      - image: circleci/python:3.7-stretch
        auth:
          username: $DOCKER_USER
          password: $DOCKER_PASS
    working_directory: ~/fun
    steps:
      - checkout
      # Make sure the changes don't add a "print" statement to the code base.
      # We should exclude the ".circleci" folder from the search as the very command that checks
      # the absence of "print" is including a "print(" itself.
      - run:
          name: enforce absence of print statements in code
          command: |
            ! git diff origin/master..HEAD -- . ':(exclude).circleci' | grep "print("
      - run:
          name: Check absence of fixup commits
          command: |
            ! git log | grep 'fixup!'
      - run:
          name: Install gitlint
          command: |
            pip install --user gitlint
      - run:
          name: lint commit messages added to master
          command: |
            ~/.local/bin/gitlint --commits origin/master..HEAD

  # Check that the CHANGELOG has been updated in the current branch
  check-changelog:
    docker:
      - image: circleci/buildpack-deps:stretch-scm
        auth:
          username: $DOCKER_USER
          password: $DOCKER_PASS
    working_directory: ~/fun
    steps:
      - checkout
      - run:
          name: Check that the CHANGELOG has been modified in the current branch
          command: |
            git whatchanged --name-only --pretty="" origin..HEAD | grep CHANGELOG

  # Check that the CHANGELOG max line length does not exceed 80 characters
  lint-changelog:
    docker:
      - image: debian:stretch
        auth:
          username: $DOCKER_USER
          password: $DOCKER_PASS
    working_directory: ~/fun
    steps:
      - checkout
      - run:
          name: Check CHANGELOG max line length
          command: |
            # Get the longuest line width (ignoring release links)
            test $(cat CHANGELOG.md | grep -Ev "^\[.*\]: https://github.com/openfun" | wc -L) -le 80

  check-configuration:
    machine:
        docker_layer_caching: true
    steps:
      - checkout
      - run:
          name: Check that the circle-ci config.yml file has been updated in the current branch
          command: bin/ci check_configuration
    working_directory: ~/fun

  # Build jobs
  #
  # Note that the job name should match the EDX_RELEASE value
  ${JOBS_LIST}

  # Hub job
  hub:
    <<: *defaults

    steps:
      - checkout

      # Login to DockerHub with encrypted credentials stored as secret
      # environment variables (set in CircleCI project settings)
      - run:
          name: Login to DockerHub
          command: echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

      # Install a recent docker-compose release
      - run:
          name: Upgrade docker-compose
          command: |
            curl -L "https://github.com/docker/compose/releases/download/1.25.1/docker-compose-$(uname -s)-$(uname -m)" -o ~/docker-compose
            chmod +x ~/docker-compose
            sudo mv ~/docker-compose /usr/local/bin/docker-compose

      # Thanks to docker layer caching, rebuilding the image should be blazing
      # fast!
      - run:
          name: Rebuild production image
          command: |
            source $(bin/ci activate_path)
            make build

      # Tag images with our DockerHub namespace (fundocker/), and list images to
      # check that they have been properly tagged.
      - run:
          name: Tag production image
          command: |
            source $(bin/ci activate_path)
            docker tag edxapp:${EDX_RELEASE}-${FLAVOR} fundocker/edxapp:${CIRCLE_TAG}
            docker images fundocker/edxapp:${CIRCLE_TAG}

      - run:
          name: Tag nginx production images
          command: |
            source $(bin/ci activate_path)
            docker tag edxapp-nginx:${EDX_RELEASE}-${FLAVOR} fundocker/edxapp-nginx:${CIRCLE_TAG}
            docker images fundocker/edxapp-nginx:${CIRCLE_TAG}

      # Publish the production images to DockerHub
      - run:
          name: Publish production image
          command: |
            docker push fundocker/edxapp:${CIRCLE_TAG}
            docker push fundocker/edxapp-nginx:${CIRCLE_TAG}

# CI workflows
workflows:
  version: 2

  # We have a single workflow
  edxapp:
    jobs:
      # Quality
      - lint-git:
          filters:
            branches:
              ignore: master
            tags:
              ignore: /.*/
      - check-changelog:
          filters:
            branches:
              ignore: master
            tags:
              ignore: /.*/
      - lint-changelog:
          filters:
            branches:
              ignore: master
            tags:
              ignore: /.*/
      - check-configuration:
          filters:
            branches:
              ignore: master
            tags:
              ignore: /.*/

      # Build jobs
      ${WORKFLOW_JOBS_LIST}

      # We are pushing to Docker only images that are the result of a tag respecting the pattern:
      #    **{branch-name}-x.y.z**
      #
      # Where branch-name is of the form: **{edx-version}[-{fork-name}]**
      #   - **edx-version:** name of the upstream `edx-platform` version (e.g. ginkgo.1),
      #   - **fork-name:** name of the specific project fork, if any (e.g. funwb).
      #
      # Some valid examples:
      #   - dogwood.3-1.0.3
      #   - dogwood.2-funmooc-17.6.1
      #   - eucalyptus-funwb-2.3.19
      - hub:
          filters:
            branches:
              ignore: /.*/
            tags:
              only: /^[a-z0-9.]*-?[a-z]*-(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/
