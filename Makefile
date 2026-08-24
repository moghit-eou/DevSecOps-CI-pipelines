.PHONY:sast sca container-scan clean

# Directory or image to scan, override on the CLI, e.g.:
#   make sast PROJECT=./mip-backend-maven 
#   make sca PROJECT=./mip-backend-maven ECOSYSTEM-TYPE= ( maven , npm , python , golang , ... ) 
#   make container-scan  IMAGE=platform-backend:local

PROJECT ?= .
IMAGE   ?= app:local


sast: ## Run the SAST pipeline against $PROJECT
	Todo later

sca: ## Run the SCA pipeline against $PROJECT
	Todo later

container-scan: ## Run the container-scan pipeline against $PROJECT
	.Todo later
