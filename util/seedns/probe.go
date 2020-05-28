package main

import (
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"
)

var HOSTNAME string

var timeSeries []int64
var tsl sync.Mutex

var errors int
var stop bool = false

func probeDNS() {
	var tmpSeries [10]int64
	HOSTNAME = os.Getenv("seednsHOSTNAME")
	rounds, _ := strconv.Atoi(os.Getenv("seednsROUNDS"))
	log.Printf("Running with rounds=%v and hostname=%v\n", rounds, HOSTNAME)
	i := 0
	r := 0
	for r < rounds {
		start := time.Now()
		_, err := net.LookupIP(HOSTNAME)
		if err != nil {
			errors++
			log.Printf("%v\n", err)
			time.Sleep(time.Second)
			continue
		}
		elapsed := time.Since(start)
		ms := elapsed.Nanoseconds() / 1000000

		tmpSeries[i] = ms
		i++
		if i == 10 {
			tsl.Lock()
			for j := 0; j < 10; j++ {
				timeSeries = append(timeSeries, tmpSeries[j])
			}
			tsl.Unlock()
			i = 0
			log.Printf("%v\n", tmpSeries)
		}
		time.Sleep(time.Second)
		r++
	}
	stop = true
	fmt.Print("\nThe handler finished running\n")
}

func metricsHandler(w http.ResponseWriter, r *http.Request) {

	switch r.Method {
	case "GET":
		tsl.Lock()
		fmt.Fprintf(w, "errors=%v\nmetrics=%v", errors, timeSeries)
		tsl.Unlock()
	}
}

func statusHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		fmt.Fprintf(w, "%v", stop)
	}
}

func main() {
	http.HandleFunc("/stop", statusHandler)
	http.HandleFunc("/metrics", metricsHandler)

	go probeDNS()

	http.ListenAndServe(":8998", nil)

	log.Printf("Running on 0.0.0.0:8998...\n")
}
