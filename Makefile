# To do stuff with make, you type `make` in a directory that has a file called
# "Makefile".  You can also type `make -f <makefile>` to use a different filename.
#
# A Makefile is a collection of rules. Each rule is a recipe to do a specific
# thing, sort of like a grunt task or an npm package.json script.
#
# A rule looks like this:
#
# <target>: <prerequisites...>
# 	<commands>
#
# The "target" is required. The prerequisites are optional, and the commands
# are also optional, but you have to have one or the other.
#
# Type `make` to show the available targets and a description of each.
#
.DEFAULT_GOAL := help
.PHONY: help
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Docker

symlink-global-docker-env: ## symlink global docker env file for local development
	@DOCKERFILES_SHARE_DIR="$HOME/.local/share/dockerfiles" \
	DOCKER_GLOBAL_ENV_FILENAME=".env.docker" \
	DOCKER_GLOBAL_ENV_FILE="$${DOCKERFILES_SHARE_DIR}/$${DOCKER_GLOBAL_ENV_FILENAME}" \
	[ -f "$${DOCKER_GLOBAL_ENV_FILE}" ] && ln -sf "$${DOCKER_GLOBAL_ENV_FILE}" .env.docker || echo "Global docker env file not found"

docker-login: ## login to docker
	@bash .docker/.docker-scripts/docker-compose.sh login

docker-build-app: ## build the docker app image
	@bash .docker/.docker-scripts/docker-compose.sh build --variant app

docker-config-app: ## show the docker app config
	@bash .docker/.docker-scripts/docker-compose.sh config --variant app

docker-push-base: ## push the docker base image
	@bash .docker/.docker-scripts/docker-compose.sh push --variant base

docker-push-app: ## push the docker app image
	@bash .docker/.docker-scripts/docker-compose.sh push --variant app

docker-run-app: ## run the docker app image
	@bash .docker/.docker-scripts/docker-compose.sh run --variant app

docker-up-app: ## launch the docker app image
	@bash .docker/.docker-scripts/docker-compose.sh up --variant app

docker-up-app-detach: ## launch the docker app image in detached mode
	@bash .docker/.docker-scripts/docker-compose.sh up --variant app --detach
