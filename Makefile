.PHONY: sast sca container-scan clean

# Directory or image to scan, override on the CLI, e.g.:
#   make sast PROJECT=./mip-backend-maven
#   make sca PROJECT=./mip-backend-maven ECOSYSTEM=maven  (maven, npm, generic, golang)
#   make container-scan IMAGE=platform-backend:local SCAN_TYPE=sca
#   make container-scan IMAGE=platform-backend:local SCAN_TYPE=sast PROJECT=./mip-backend-maven

PROJECT   ?= .
ECOSYSTEM ?= generic
IMAGE     ?=
SCAN_TYPE ?=

sast: ## Run the SAST pipeline against $PROJECT
	./toolbox.sh sast $(PROJECT)

sca: ## Run the SCA pipeline against $PROJECT for $ECOSYSTEM
	./toolbox.sh sca $(PROJECT) $(ECOSYSTEM)

container-scan: ## Run the container-scan pipeline ($SCAN_TYPE: sast|sca) against $IMAGE
	./toolbox.sh container-scan $(IMAGE) $(SCAN_TYPE) $(PROJECT)

clean: ## Remove local SARIF outputs and toolbox images
	rm -f *.sarif */*.sarif
	docker image rm -f mip-toolbox:sast mip-toolbox:sca mip-toolbox:container-scan 2>/dev/null || true