#!/bin/bash
# add your custom commands here that should be executed when building the docker image
# arguments usage
USAGE="
$0 COMMAND [OPTIONS]

Arguments:
COMMAND                The operation to be performed. Must be one of: [build|config|push|login|up|down|run]

Options:
-v, --variant IMAGE_VARIANT     Specify a variant for the Docker image.
-r, --run RUN_COMMAND           Specify a command to run when using the 'run' command. Default: bash
-h, --help                      Display this help message.

Additional arguments can be provided after the Docker name, and they will be passed directly to the Docker Compose command.

Example:
$0 build -v base
"

# declare arguments
COMMAND="build"
VARIANT="base"
RUN_COMMAND=""
ADDITIONAL_ARGS=""

set +u
# read arguments
# first argument is the command
COMMAND="$1"
shift

# parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
    -v | --variant)
        VARIANT="$2"
        shift
        ;;
    --variant=*)
        VARIANT="${1#*=}"
        ;;
    -r | --run)
        RUN_COMMAND="$2"
        shift
        ;;
    --run=*)
        RUN_COMMAND="${1#*=}"
        ;;
    -h | --help)
        echo "Usage: $0 $USAGE" >&2
        exit 0
        ;;
    -h*)
        echo "Usage: $0 $USAGE" >&2
        exit 0
        ;;
    *)
        ADDITIONAL_ARGS="$ADDITIONAL_ARGS $1"
        ;;
    esac
    shift
done
# check if remaining arguments exist
if [[ -n "$ADDITIONAL_ARGS" ]]; then
    echo "Additional arguments: $ADDITIONAL_ARGS" >&2
fi
set -u

if [ "${COMMAND}" == "build" ]; then
    echo "Building docker image for variant: ${VARIANT}"
elif [ "${COMMAND}" == "config" ]; then
    echo "Printing docker config for variant: ${VARIANT}"
elif [ "${COMMAND}" == "push" ]; then
    echo "Pushing docker image for variant: ${VARIANT}"
elif [ "${COMMAND}" == "up" ]; then
    echo "Starting docker container for variant: ${VARIANT}"
elif [ "${COMMAND}" == "down" ]; then
    echo "Stopping docker container for variant: ${VARIANT}"
elif [ "${COMMAND}" == "run" ]; then
    echo "Running docker container for variant: ${VARIANT}"
elif [ "${COMMAND}" == "login" ]; then
    echo "Logging into docker registry for variant: ${VARIANT}"
else
    echo "Invalid command: $COMMAND" >&2
    echo "Usage: $0 $USAGE" >&2
    exit 1
fi
echo "---"

# load environment variables and print them
set -a
# load secert environment variables from .env.secret
DOCKER_SECRET_ENV_FILENAME=${DOCKER_SECRET_ENV_FILENAME:-".env.secret"}
if [ -e "${DOCKER_SECRET_ENV_FILENAME}" ]; then
    echo "Loading secret environment variables from ${DOCKER_SECRET_ENV_FILENAME}"
    set -x # print commands and thier arguments
    # shellcheck disable=SC1091,SC1090
    source "${DOCKER_SECRET_ENV_FILENAME}"
    set +x # disable printing of environment variables
fi
# load global environment variables from .env.docker
DOCKERFILES_SHARE_DIR=${DOCKERFILES_SHARE_DIR:-"$HOME/.local/share/dockerfiles"}
DOCKER_GLOBAL_ENV_FILENAME=${DOCKER_GLOBAL_ENV_FILENAME:-".env.docker"}
DOCKER_GLOBAL_ENV_FILE=${DOCKER_GLOBAL_ENV_FILE:-"${DOCKERFILES_SHARE_DIR}/${DOCKER_GLOBAL_ENV_FILENAME}"}
if [ ! -e "${DOCKER_GLOBAL_ENV_FILENAME}" ] && [ -e "${DOCKER_GLOBAL_ENV_FILE}" ]; then
    echo "Symlinking ${DOCKER_GLOBAL_ENV_FILE} to ${DOCKER_GLOBAL_ENV_FILENAME}"
    ln -s "${DOCKER_GLOBAL_ENV_FILE}" "${DOCKER_GLOBAL_ENV_FILENAME}"
fi
if [ -e "${DOCKER_GLOBAL_ENV_FILENAME}" ]; then
    echo "Loading global environment variables from ${DOCKER_GLOBAL_ENV_FILENAME}"
    set -x # print commands and thier arguments
    # shellcheck disable=SC1091,SC1090
    source "${DOCKER_GLOBAL_ENV_FILENAME}"
    set +x # disable printing of environment variables
fi
# shellcheck disable=SC1091
source .docker/docker.version
if [ -e .docker/docker.common.env ]; then
    echo "Loading common environment variables from .docker/docker.common.env"
    set -x # print commands and thier arguments
    # shellcheck disable=SC1091
    source .docker/docker.common.env
    set +x # disable printing of environment variables
fi
if [ -e ".docker/docker.${VARIANT}.env" ]; then
    echo "Loading environment variables from .docker/docker.${VARIANT}.env"
    set -x # print commands and thier arguments
    # shellcheck disable=SC1091,SC1090
    source ".docker/docker.${VARIANT}.env"
    set +x # disable printing of environment variables
fi
set +a

# prepare docker network
if [[ -n "${CONTAINER_NETWORK_NAME}" ]] && ! docker network ls | grep -q "${CONTAINER_NETWORK_NAME}"; then
    echo "Creating network ${CONTAINER_NETWORK_NAME}"
    docker network create "${CONTAINER_NETWORK_NAME}"
else
    echo "Network ${CONTAINER_NETWORK_NAME} already exists."
fi

# run docker-compose
if [ "${COMMAND}" == "push" ]; then
    CMD="docker push ${CONTAINER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
elif [ "${COMMAND}" == "login" ]; then
    echo "GITHUB_CR_PAT: $GITHUB_CR_PAT"
    CMD="docker login ghcr.io -u $GITHUB_USERNAME"
elif [ "${COMMAND}" == "run" ]; then
    CMD="docker compose --project-directory . -f .docker/docker-compose.${VARIANT}.yaml run workspace ${RUN_COMMAND} ${ADDITIONAL_ARGS}"
else
    CMD="docker-compose --project-directory . -f .docker/docker-compose.${VARIANT}.yaml ${COMMAND} ${ADDITIONAL_ARGS}"
fi
echo "Running command: ${CMD}"
eval "${CMD}"
