.PHONY: build build-sast build-sca build-container-scan sast sca container-scan shell-sast shell-sca shell-container-scan clean

# Directory to scan, override on the CLI, e.g.:
#   make sca PROJECT=./mip-backend-maven
PROJECT ?= .
IMAGE   ?= app:local


sast: ## Run the SAST pipeline against $PROJECT
	Todo later

sca: ## Run the SCA pipeline against $PROJECT
	Todo later

container-scan: ## Run the container-scan pipeline against $PROJECT
	.Todo later
