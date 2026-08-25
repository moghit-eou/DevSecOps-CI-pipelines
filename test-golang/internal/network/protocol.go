package network

type Request struct {
	Type    string `json:"_type_"`
	Payload string `json:"_payload_"`
}

/*
request.json example

	{
	    "_Type_": "job",
	    "_payload_": "ls"
	}
*/
type Response struct {
	Status  string `json:"status_"`
	Message string `json:"message_"`
	// json name is used during testing calls
	// Message in GO , message in json
	// it's a mapping layer
}
