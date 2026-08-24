# =============================================================================
# Stage: toolbox-base -- shared by all three pipelines
# =============================================================================
FROM ubuntu:24.04 AS toolbox-base



# =============================================================================
# Stage: sast-toolbox -- OpenGrep only
# =============================================================================
FROM toolbox-base AS sast-toolbox
# TODO for later

# =============================================================================
# Stage: sca-toolbox -- Trivy + OSV-Scanner + Maven (for SBOM generation)
# =============================================================================
FROM toolbox-base AS sca-toolbox

#Todo for later 

# =============================================================================
# Stage: container-scan-toolbox -- Trivy + OSV-Scanner + OpenGrep + Hadolint
#                                    + Docker CLI (docker-outside-of-docker)
# =============================================================================
FROM toolbox-base AS container-scan-toolbox
# Todo for later 
