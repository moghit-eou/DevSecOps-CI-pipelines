package execution

import (
	"bytes"
	"context"
	"fmt"

	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/client"
	"github.com/docker/docker/pkg/stdcopy"
)

type DockerExecutor struct {
	cli   *client.Client
	image string
}

// compile time check. if DockerExecutor is missing a method, this line
var _ Executor = (*DockerExecutor)(nil)

func NewDockerExecutor(image string) (*DockerExecutor, error) {
	cli, err := client.NewClientWithOpts(
		client.FromEnv,
		client.WithAPIVersionNegotiation(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create docker client: %w", err)
	}
	return &DockerExecutor{cli: cli, image: image}, nil
}

func (d *DockerExecutor) Run(ctx context.Context, command string) (*Result, error) {
	cfg := &container.Config{
		Image: d.image,
		Cmd:   []string{"sh", "-c", command},
		Tty:   false, // merges stdout and stderr into one stream
	}

	resp, err := d.cli.ContainerCreate(ctx, cfg, nil, nil, nil, "")
	if err != nil {
		return nil, fmt.Errorf("container create failed: %w", err)
	}

	// every subsequent call (Start, Wait, Logs, Remove) needs this ID
	containerID := resp.ID

	defer func() {
		_ = d.cli.ContainerRemove(
			context.Background(),
			containerID,
			container.RemoveOptions{Force: true},
		)
	}()

	if err := d.cli.ContainerStart(ctx, containerID, container.StartOptions{}); err != nil {
		return nil, fmt.Errorf("container start failed: %w", err)
	}

	statusCh, errCh := d.cli.ContainerWait(ctx, containerID, container.WaitConditionNotRunning)
	var exitCode int64
	select {
	case <-ctx.Done():
		return nil, fmt.Errorf("container timed out: %w", ctx.Err())
	case err := <-errCh:
		if err != nil {
			return nil, fmt.Errorf("container wait error: %w", err)
		}
	case status := <-statusCh:
		exitCode = status.StatusCode
	}

	out, err := d.cli.ContainerLogs(
		context.Background(),
		containerID,
		container.LogsOptions{ShowStdout: true, ShowStderr: true},
	)
	if err != nil {
		return nil, fmt.Errorf("log retrieval failed: %w", err)
	}
	defer out.Close()

	var stdout, stderr bytes.Buffer
	if _, err := stdcopy.StdCopy(&stdout, &stderr, out); err != nil {
		return nil, fmt.Errorf("log demux failed: %w", err)
	}

	return &Result{
		Stdout:   stdout.String(),
		Stderr:   stderr.String(),
		ExitCode: int(exitCode),
	}, nil
}

func (d *DockerExecutor) Close() error {
	if err := d.cli.Close(); err != nil {
		return fmt.Errorf("failed to close docker client: %w", err)
	}
	return nil
}
