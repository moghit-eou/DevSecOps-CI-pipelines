package control

import (
	"context"
	"fmt"

	"node-agent/internal/execution"
)

type Handler struct {
	exec execution.Executor
}

func NewHandler(exec execution.Executor) *Handler {
	return &Handler{exec: exec}
}

func (h *Handler) HandleJob(ctx context.Context, commandPayLoad string) (string, error) {
	if commandPayLoad == "" {
		return "", fmt.Errorf("empty command")
	}

	result, err := h.exec.Run(ctx, commandPayLoad)
	if err != nil {
		return "", fmt.Errorf("execution failed: %w", err)
	}

	response := fmt.Sprintf("Stdout: %s\nStderr: %s\nExitCode: %d",
		result.Stdout, result.Stderr, result.ExitCode)

	return response, nil
}
