.PHONY: sast sca container-scan clean

# Directory or image to scan, override on the CLI, e.g.:
#   make sast PROJECT=./mip-backend-maven
#   make sca PROJECT=./mip-backend-maven ECOSYSTEM=maven  (maven, npm, generic, golang)
#   make container-scan PROJECT=./mip-backend-maven IMAGE=platform-backend:local SCAN-TYPE=(sca or sast or both)

PROJECT   ?= .
ECOSYSTEM ?= maven
IMAGE     ?= app:local

sast: ## Run the SAST pipeline against $PROJECT
	./toolbox.sh sast $(PROJECT)

sca: ## Run the SCA pipeline against $PROJECT for $ECOSYSTEM
	./toolbox.sh sca $(PROJECT) $(ECOSYSTEM)

container-scan: ## Build $IMAGE from $PROJECT and run the container-scan pipeline
	./toolbox.sh container-scan $(PROJECT) $(IMAGE)

clean: ## Remove local SARIF outputs and toolbox images
	rm -f *.sarif */*.sarif
	docker image rm -f mip-toolbox:sast mip-toolbox:sca mip-toolbox:container-scan 2>/dev/null || true