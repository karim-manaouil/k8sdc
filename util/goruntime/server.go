package main

import (
	"io/ioutil"
	"log"
	"net/http"
	"sync/atomic"
	"time"
)

var buffer []byte
var avg time.Duration = 0
var totalRequests uint64 = 0

func httpHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		/* simulates calculation */
		time.Sleep(time.Duration(50) * time.Millisecond)
		w.Write(buffer)
		atomic.AddUint64(&totalRequests, 1)
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
		w.Write([]byte{'!', '!'})
	}
}

func main() {
	buffer, _ = ioutil.ReadFile("BigFile")

	http.HandleFunc("/serv", httpHandler)

	status := func() {
		for {
			log.Printf("Processed %v requests\n", totalRequests)
			time.Sleep(time.Second * 2)
		}
	}

	go status()

	http.ListenAndServe(":8998", nil)

}
