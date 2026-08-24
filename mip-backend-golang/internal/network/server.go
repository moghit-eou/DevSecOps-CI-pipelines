package network

import (
	"context"
	"encoding/json"
	"io"
	"log"
	"net"
	"time"

	"node-agent/internal/control"
)

type Server struct {
	handler *control.Handler
}

func NewServer(handler *control.Handler) *Server {
	return &Server{handler: handler}
}

func (s *Server) Start(port string) {
	Listener, err := net.Listen("tcp", ":"+port)
	if err != nil {
		log.Print("error starting server: " + err.Error())
		return
	}

	log.Println("server is listening on port " + port + "")
	defer Listener.Close() // runs after function exist

	for {
		// conn : tcp socket
		// Listener : door to the socket ( bound to a port )

		conn, err := Listener.Accept()
		if err != nil {
			log.Print("error accepting connection: " + err.Error())
			continue
		}
		log.Println("new connection from", conn.RemoteAddr())
		go s.handleConnection(conn)
	}
}

func (s *Server) handleConnection(conn net.Conn) error {
	defer conn.Close()

	conn.SetReadDeadline(time.Now().Add(10 * time.Second))

	// conn is a stream of bytes
	// I need to decode it into a Request struct and encode the Response struct back to the client
	decoder := json.NewDecoder(conn)
	encoder := json.NewEncoder(conn)

	for {

		request := Request{}
		err := decoder.Decode(&request)

		if err == io.EOF {
			log.Printf("client %s disconnected", conn.RemoteAddr())
			return nil
		}

		if err != nil {
			log.Printf("decoding request failed: %v", err)
			return err
		}

		log.Printf("Received request : Type = %s, Payload = %s",
			request.Type, request.Payload)

		var response Response

		switch request.Type {

		case "health-check":
			response = Response{Status: "ok", Message: "healthy"}

		case "job":
			result, err := s.handler.HandleJob(context.Background(), request.Payload)

			if err != nil {
				response = Response{Status: "error", Message: err.Error()}
			} else {
				response = Response{Status: "success", Message: result}
			}

		default:
			response = Response{Status: "error", Message: "Unknown request type"}

		}

		err = encoder.Encode(response)
		if err != nil {
			log.Printf("sending response failed: %v", err)
		}

	}
	return nil
}
