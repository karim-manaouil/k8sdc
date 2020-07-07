package main

import (
	"fmt"
	"github.com/sparrc/go-ping"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"
)

var HOSTNAME string

var timeSeries []time.Duration
var tsl sync.Mutex

var errors int
var stop bool = false

func probeDNS() {
	var tmpSeries [10]time.Duration
	HOSTNAME = os.Getenv("seednsHOSTNAME")
	rounds, _ := strconv.Atoi(os.Getenv("seednsROUNDS"))
	log.Printf("Running with rounds=%v and hostname=%v\n", rounds, HOSTNAME)

	i := 0
	r := 0
	for r < rounds {
		//ips, err := net.LookupIP(HOSTNAME)
		pinger, err := ping.NewPinger(HOSTNAME)
		pinger.SetPrivileged(true)
		if err != nil {
			panic(err)
		}
		pinger.Count = 1
		pinger.Run() // blocks until finished
		stats := pinger.Statistics()
		if stats.PacketsRecv != 1 {
			errors++
			log.Fatal("Host unreachable")
		}
		log.Printf("addr=%v rtt=%v\n", pinger.IPAddr(), stats.AvgRtt)

		tmpSeries[i] = stats.AvgRtt
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
