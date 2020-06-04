package main

import (
	"io/ioutil"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"
)

var avgs [1000]time.Duration
var mu [1000]sync.Mutex

func sendRequest() {
	start := time.Now()
	resp, err := http.Get(os.Getenv("SRVIP"))
	if err != nil {
		log.Fatal(err)
	}
	elapsed := time.Since(start)
	r := rand.Uint64() % 1000

	mu[r].Lock()
	avgs[r] = (avgs[r] + elapsed) / 2
	mu[r].Unlock()

	/* Make sure Go doesn't optimize this out */
	if resp.StatusCode == http.StatusOK {
		defer resp.Body.Close()
		bytes, _ := ioutil.ReadAll(resp.Body)
		if err != nil {
			log.Fatal(err)
		}
		ioutil.WriteFile("/dev/null", bytes, 0644)
	}
}

func main() {
	log.Printf("Using %s as server", os.Getenv("SRVIP"))
	C, _ := strconv.Atoi(os.Getenv("C"))
	for cycle := 0; cycle < C; cycle++ {
		start := time.Now()
		R, _ := strconv.Atoi(os.Getenv("R"))
		r := 0
		for r < R {
			go sendRequest()
			r++
			if (time.Since(start)) > time.Second {
				break
			}
		}
		log.Printf("Cycle %v achived %v/%v throughput\n", cycle, r, R)
		time.Sleep(time.Second * 1)
	}

	var avg time.Duration = 0
	for i := 0; i < 1000; i++ {
		avg = avg + avgs[i]
	}
	log.Printf("Average request duration: %v", avg/1000)
}
