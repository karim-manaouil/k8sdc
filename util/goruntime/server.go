package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"math/rand"
	"net/http"
	"strconv"
	"time"
)

var buffer []byte
var avg time.Duration = 0

func generateRandList() []byte {
	le := rand.Uint64() % 10
	var s string
	var i uint64

	for i = 0; i < le; i++ {
		s += strconv.FormatUint(rand.Uint64(), 10)
	}
	return []byte(s)
}

func httpHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	switch r.Method {

	case "GET":
		s := generateRandList()
		w.Write(append(buffer, s...))
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
		fmt.Fprintf(w, "!!")
	}

	elapsed := time.Since(start)
	avg = (avg + elapsed) / 2
}

func avgHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		fmt.Fprintf(w, "Average request duration: %v\n", avg)
	}
}

func main() {
	buffer, _ = ioutil.ReadFile("BigFile")

	http.HandleFunc("/serv", httpHandler)
	http.HandleFunc("/avg", avgHandler)

	log.Println("Go!")
	http.ListenAndServe(":8998", nil)
}
