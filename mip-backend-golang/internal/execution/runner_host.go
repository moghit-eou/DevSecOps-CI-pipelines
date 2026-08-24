package execution

import (
	"bytes"
	"os/exec"
)

/*Only files with the same package
can directly use each other types without import */

func RunCommand_2(command string) (*Result, error) {
	cmd := exec.Command("sh", "-c", command)

	var stdout, stderr bytes.Buffer

	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()

	exitCode, runErr := extractExitCode(err)
	if runErr != nil {
		return nil, runErr
	}

	return &Result{
		Stdout:   stdout.String(),
		Stderr:   stderr.String(),
		ExitCode: exitCode,
	}, nil
}

func extractExitCode(err error) (int, error) {
	if err == nil {
		return 0, nil // process run Success
	}

	if exitErr, ok := err.(*exec.ExitError); ok {
		return exitErr.ExitCode(), nil
		// it could be a logical falure , run and failed
	}

	return 0, err // OS failure
}
