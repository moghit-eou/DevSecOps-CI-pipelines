import subprocess
import os
import sys
import logging
import json
import argparse
from parse_sarif import evaluate


GREEN = '\033[92m'
RED = '\033[91m'
RESET = '\033[0m'
BOLD = '\033[1m'
YELLOW = '\033[93m'

logging.basicConfig(
    level=logging.INFO,
    format='%(message)s'  # Clean format to prevent double-timestamps in CI logs
)
logger = logging.getLogger("container-scan-orchestrator")

# --- Configurable values
IMAGE_NAME = os.getenv("IMAGE_NAME", "platform-ui:local")

# --- SCA / CVE (Trivy + OSV) ---
TRIVY_IGNOREFILE = os.getenv("TRIVY_IGNOREFILE", "ci/suppress_trivy.yaml")
OSV_IGNOREFILE = os.getenv("OSV_IGNOREFILE", "ci/suppress_osv_scanner.toml")
TRIVY_SCA_SARIF_OUTPUT = os.getenv("TRIVY_SCA_SARIF_OUTPUT", "sca-trivy-container.sarif")
OSV_SCA_SARIF_OUTPUT = os.getenv("OSV_SCA_SARIF_OUTPUT", "sca-osv-container.sarif")

# --- SAST/Code Linting (OpenGrep + Hadolint) ---
SEMGREP_CONFIG_RULESETS = os.getenv(
    "SEMGREP_CONFIG_RULESETS",
    "semgrep-rules/dockerfile"
).split()
OPENGREP_SAST_SARIF_OUTPUT = os.getenv("OPENGREP_SAST_SARIF_OUTPUT", "sast-opengrep-dockerfile.sarif")
HADOLINT_SAST_SARIF_OUTPUT = os.getenv("HADOLINT_SAST_SARIF_OUTPUT", "sast-hadolint-dockerfile.sarif")

# --- Functions to run each SCA tool and handle their outputs
def run_trivy():
    cmd = [
        "trivy", "image",
        IMAGE_NAME,
        "--format", "sarif",
        "--ignorefile", TRIVY_IGNOREFILE,
        "--output", TRIVY_SCA_SARIF_OUTPUT
    ]
    return subprocess.run(cmd).returncode

def run_osv_scanner():
    cmd = [
        "osv-scanner", "scan", "image",
        IMAGE_NAME,
        "--config", OSV_IGNOREFILE,
        "--format", "sarif",
        "--output-file", OSV_SCA_SARIF_OUTPUT
    ]
    exit_code = subprocess.run(cmd).returncode
    if exit_code == 1:
        return 0  # OSV Scanner returns 1 if vulnerabilities are found, but we want to continue the pipeline
    return exit_code

def handle_sca():

    tools = {"trivy": run_trivy, "osv-scanner": run_osv_scanner}
    sarif_files = {"trivy": TRIVY_SCA_SARIF_OUTPUT, "osv-scanner": OSV_SCA_SARIF_OUTPUT}
    tool_status = {}   # "PASSED" | "WARNING" | "FAILED" | "ERROR"
    gate_failed = False

    # Run each SCA tool and collect their exit codes
    for name, tool_fn in tools.items():
        exit_code = tool_fn()
        logger.info("-" * 40)

        path = sarif_files[name]
        if exit_code != 0 and os.path.exists(path):
            logger.error(f"{RED}[!] {name} exit code {exit_code} but wrote {path}{RESET}")
            tool_status[name] = "ERROR"
            gate_failed = True

    # Evaluate each SARIF file for gate decision
    for name, path in sarif_files.items():
        if name in tool_status:
            continue  # already flagged ERROR above, don't overwrite it

        if not os.path.exists(path):
            logger.error(f"{RED}[!] {name} SARIF missing: {path},tool failed to run (not a vulnerability){RESET}")
            tool_status[name] = "ERROR"
            gate_failed = True
            continue

        eval_result = evaluate(path)

        if eval_result.gate_failed:
            tool_status[name] = "FAILED"          # this tool found CVSS >= 8.0
            gate_failed = True
        elif eval_result.gate_warn:
            tool_status[name] = "WARNING"         # this tool found 5.0 <= CVSS < 8.0
        else:
            tool_status[name] = "PASSED"          # this tool found nothing >= 5.0

    # Print summary of results
    logger.info(f"\n{BOLD}========== SCA PIPELINE SUMMARY =========={RESET}")
    for name, status in tool_status.items():
        if status == "PASSED":
            logger.info(f"[{name}]: {GREEN}PASSED{RESET}")
        elif status == "WARNING":
            logger.warning(f"[{name}]: {YELLOW}WARNING (findings between 5.0 and 8.0){RESET}")
        elif status == "ERROR":
            logger.error(f"[{name}]: {RED}ERROR (tool did not run correctly){RESET}")
        else:
            logger.error(f"[{name}]: {RED}FAILED (CVSS >= 8.0 found){RESET}")
    logger.info(f"{BOLD}=========================================={RESET}\n")

    # Exit with non-zero code if any tool failed the gate
    if gate_failed:
        logger.error(f"{RED}One or more SCA tools failed the gate check.{RESET}")
        sys.exit(1)


# --- Functions to run each SAST tool and handle their outputs
def run_hadolint():
    cmd = [
        "hadolint", "Dockerfile",
        "--failure-threshold", "error",
        "--format", "sarif",
    ]
    with open(HADOLINT_SAST_SARIF_OUTPUT, "w") as f:
        result = subprocess.run(cmd, stdout=f)

    return result.returncode

def run_opengrep():
    base_cmd = ["opengrep", "scan", "--include=Dockerfile", "-q"] + \
        [f"--config {config}" for config in SEMGREP_CONFIG_RULESETS]

    report_cmd = (base_cmd + ["--sarif", "--output", OPENGREP_SAST_SARIF_OUTPUT])
    report_cmd = " ".join(report_cmd).split()
    logger.info(f"{BOLD}Running (report):{RESET} {' '.join(report_cmd)}")
    subprocess.run(report_cmd)

    gate_cmd = (base_cmd + ["--severity=ERROR", "--error"])
    gate_cmd = " ".join(gate_cmd).split()
    logger.info(f"{BOLD}Running (gate):{RESET} {' '.join(gate_cmd)}")
    return subprocess.run(gate_cmd).returncode

def handle_sast():
    tools = {
        "hadolint": run_hadolint,
        "opengrep": run_opengrep,
    }

    tool_status = {}
    exit_codes = {}

    for name, run_fn in tools.items():
        exit_code = run_fn()
        exit_codes[name] = exit_code
        if exit_code == 0:
            tool_status[name] = "PASSED"
        elif exit_code == 1:
            tool_status[name] = "FAILED"
        else:
            tool_status[name] = "ERROR"

    logger.info(f"\n{BOLD}========== SAST PIPELINE SUMMARY =========={RESET}")
    for name, status in tool_status.items():
        if status == "PASSED":
            logger.info(f"[{name}]: {GREEN}PASSED (exit code 0){RESET}")
        elif status == "FAILED":
            logger.error(f"[{name}]: {RED}FAILED (exit code 1 - error-severity findings){RESET}")
        else:
            logger.error(f"[{name}]: {RED}ERROR (exit code {exit_codes[name]}, tool did not run correctly){RESET}")
    logger.info(f"{BOLD}==========================================={RESET}\n")

    if any(status != "PASSED" for status in tool_status.values()):
        sys.exit(1)

def merge_sarifs(sarif_paths, output_path):
    merged = {
        "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json",
        "version": "2.1.0",
        "runs": [],
    }

    for path in sarif_paths:
        if not os.path.exists(path):
            logger.warning(f"{path} not found, skipping in merge")
            continue
        with open(path) as f:
            sarif = json.load(f, strict=False)
        merged["runs"].extend(sarif.get("runs", []))

    with open(output_path, "w") as f:
        json.dump(merged, f)

    logger.info(f"SARIF files merged successfully into {output_path}")

def main():
    parser = argparse.ArgumentParser(
        prog="sec-orchestrator",
        description="Agnostic DevSecOps Container scanning Pipeline Orchestrator"
    )

    # The primary router
    parser.add_argument(
        "-s", "--scan-type",
        choices=["sast", "sca"],
        help="Specify the security methodology to execute (e.g., sast, sca)"
    )

    # Image flag specifically SCA approach
    parser.add_argument(
        "-i", "--image",
        help="Target Docker image reference"
    )

    parser.add_argument(
    "--merge-sarif",
    nargs="+",
    metavar="SARIF_FILE",
    help="List of SARIF files to merge into one report"
    )

    parser.add_argument(
        "--merge-output",
        default="merged-container-scan.sarif",
        help="Output path for the merged SARIF file"
    )
    args = parser.parse_args()

    if args.scan_type == "sast":
        logger.info(f"{BOLD}Initiating SAST pipeline: {RESET}")
        handle_sast()
    # Execution
    elif args.scan_type == "sca":
        logger.info(f"{BOLD}Initiating SCA pipeline on {args.image}{RESET}")
        global IMAGE_NAME
        if args.image:               # Override the global IMAGE_NAME
            IMAGE_NAME = args.image
        handle_sca()

    if args.merge_sarif:
        merge_sarifs(args.merge_sarif, args.merge_output)
        return

if __name__ == "__main__":
    main()
