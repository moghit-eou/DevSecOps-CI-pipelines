package execution

import (
	"context"
)

type Result struct {
	Stdout   string
	Stderr   string
	ExitCode int
}

type Executor interface {
	Run(ctx context.Context, command string) (*Result, error)
	Close() error
}
