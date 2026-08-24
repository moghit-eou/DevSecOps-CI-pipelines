.PHONY: build build-sast build-sca build-container-scan sast sca container-scan shell-sast shell-sca shell-container-scan clean

# Directory to scan, override on the CLI, e.g.:
#   make sca PROJECT=./mip-backend-maven
PROJECT ?= .
IMAGE   ?= app:local

build: ## Build all three toolbox images
	./toolbox.sh build all

build-sast:
	./toolbox.sh build sast

build-sca:
	./toolbox.sh build sca

build-container-scan:
	./toolbox.sh build container-scan

sast: ## Run the SAST pipeline against $PROJECT
	./toolbox.sh sast "$(PROJECT)"

sca: ## Run the SCA pipeline against $PROJECT
	./toolbox.sh sca "$(PROJECT)"

container-scan: ## Run the container-scan pipeline against $PROJECT
	./toolbox.sh container-scan "$(PROJECT)" "$(IMAGE)"

shell-sast:
	./toolbox.sh shell sast "$(PROJECT)"

shell-sca:
	./toolbox.sh shell sca "$(PROJECT)"

shell-container-scan:
	./toolbox.sh shell container-scan "$(PROJECT)"

clean: ## Remove all toolbox images
	-docker rmi mip-toolbox:sast mip-toolbox:sca mip-toolbox:container-scan 2>/dev/null

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'
