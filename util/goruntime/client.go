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

var IP string

func sendRequest() {
	start := time.Now()
	resp, err := http.Get(IP)
	if err != nil {
		log.Println(err)
		return
	}
	elapsed := time.Since(start)
	r := rand.Uint64() % 1000

	mu[r].Lock()
	avgs[r] = avgs[r] + elapsed
	avgc[r] = avgc[r] + 1
	mu[r].Unlock()

	avgb[r] = true

	if resp.StatusCode == http.StatusOK {
		defer resp.Body.Close()
		io.Copy(ioutil.Discard, resp.Body)
	}

	goel := time.Since(start)
	log.Printf("Goroutine took %v\n", goel)
}

func main() {
	IP = os.Getenv("SRVIP")
	log.Printf("Using %s as server", IP)
	C, _ := strconv.Atoi(os.Getenv("CYCLES"))
	Q, _ := strconv.Atoi(os.Getenv("QPS"))
	B, _ := strconv.Atoi(os.Getenv("BREAK"))
	W, _ := strconv.Atoi(os.Getenv("PAUSE"))

	for cycle := 0; cycle < C; cycle++ {
		start := time.Now()
		r := 0
		for r < Q {
			go sendRequest()
			r++
			if (time.Since(start)) > time.Second {
				log.Println("Break")
				break
			}
			/* Uniform distribution of threads over time */
			if r%B == 0 {
				time.Sleep(time.Duration(W) * time.Microsecond)
			}
		}
		/* If we finished in less than a second then we
		 * have to wait until the second is elapsed */
		time.Sleep(time.Second - time.Since(start))
		//log.Printf("Cycle %v achived %v/%v throughput\n", cycle, r, R)
	}

	var avg time.Duration = 0
	total := 0
	for i := 0; i < 1000; i++ {
		if avgb[i] == true {
			avg = avg + avgs[i]/time.Duration(avgc[i])
			total = total + 1
		}
	}
	log.Printf("Average request duration: %v", avg/time.Duration(total))
}
