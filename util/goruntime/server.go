package main

import (
	"fmt"
	"io/ioutil"
	"math/rand"
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
		time.Sleep(time.Duration(rand.Intn(50)) * time.Millisecond)
		w.Write(buffer)
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
		fmt.Fprintf(w, "!!")
	}
	atomic.AddUint64(&totalRequests, 1)
}

func main() {
	buffer, _ = ioutil.ReadFile("BigFile")

	http.HandleFunc("/serv", httpHandler)

	status := func() {
		for {
			fmt.Printf("Processed %v requests\n", totalRequests)
			time.Sleep(time.Second * 2)
		}
	}

	go status()

	http.ListenAndServe(":8998", nil)

}
