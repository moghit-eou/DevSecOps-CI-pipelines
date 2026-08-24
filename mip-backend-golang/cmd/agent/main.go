package main

import (
	"log"
	"os"

	"node-agent/internal/control"
	"node-agent/internal/execution"
	"node-agent/internal/network"
)

func main() {
	if len(os.Args) < 2 {
		log.Println("usage: go run main.go <port> !!!") // should avoid 1-1023 ports
		return
	}

	port := os.Args[1]
	exec, err := execution.NewDockerExecutor("alpine")
	if err != nil {
		log.Fatalf("failed to create executor: %v", err)
	}

	defer exec.Close()

	handler := control.NewHandler(exec)
	server := network.NewServer(handler)

	server.Start(port)
}
