package main

import (
	"io"
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
var avgc [1000]uint
var avgb [1000]bool

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
	avgs[r] = avgs[r] + elapsed
	avgc[r] = avgc[r] + 1
	mu[r].Unlock()

	avgb[r] = true

	/* Make sure Go doesn't optimize this out */
	if resp.StatusCode == http.StatusOK {
		defer resp.Body.Close()
		if err != nil {
			log.Fatal(err)
		}
		io.Copy(ioutil.Discard, resp.Body)
	}
}

func main() {
	log.Printf("Using %s as server", os.Getenv("SRVIP"))
	C, _ := strconv.Atoi(os.Getenv("C"))
	R, _ := strconv.Atoi(os.Getenv("R"))
	W, _ := strconv.Atoi(os.Getenv("W"))

	for cycle := 0; cycle < C; cycle++ {
		start := time.Now()
		r := 0
		for r < R {
			go sendRequest()
			r++
			if (time.Since(start)) > time.Second {
				break
			}
		}
		log.Printf("Cycle %v achived %v/%v throughput\n", cycle, r, R)
		time.Sleep(time.Duration(W) * time.Millisecond)
	}

	var avg time.Duration = 0
	total := 0
	for i := 0; i < 1000; i++ {
		if avgb[i] {
			avg = avg + avgs[i]/time.Duration(avgc[i])
			total = total + 1
		}
	}
	log.Printf("Average request duration: %v", avg/time.Duration(total))
}
