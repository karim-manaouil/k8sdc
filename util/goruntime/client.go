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
var min [1000]time.Duration
var max [1000]time.Duration
var avgc [1000]uint
var avgb [1000]bool

var mu [1000]sync.Mutex

var IP string

var wg sync.WaitGroup

var CusClient *http.Client

func sendRequest(er *int, rl *sync.Mutex) {
	start := time.Now()
	resp, err := CusClient.Get(IP)

	wg.Done()

	if err != nil {
		log.Print(err)
		return
	}
	if resp.StatusCode != http.StatusOK {
		/* We must retry */
		log.Printf("HTTP request failed: %v", resp.StatusCode)
		return
	}

	rl.Lock()
	*er = *er + 1
	rl.Unlock()

	elapsed := time.Since(start)
	r := rand.Uint64() % 1000

	mu[r].Lock()
	avgs[r] = avgs[r] + elapsed
	avgc[r] = avgc[r] + 1

	if elapsed < min[r] {
		min[r] = elapsed
	}

	if elapsed > max[r] {
		max[r] = elapsed
	}
	mu[r].Unlock()

	avgb[r] = true

	if resp.StatusCode == http.StatusOK {
		defer resp.Body.Close()
		io.Copy(ioutil.Discard, resp.Body)
	}

	// goel := time.Since(start)
	//log.Printf("Goroutine took %v\n", goel)
}

func main() {
	IP = os.Getenv("SRVIP")
	log.Printf("Using %s as server", IP)
	C, _ := strconv.Atoi(os.Getenv("CYCLES"))
	Q, _ := strconv.Atoi(os.Getenv("QPS"))
	B, _ := strconv.Atoi(os.Getenv("BREAK"))
	W, _ := strconv.Atoi(os.Getenv("PAUSE"))

	for i := 0; i < 1000; i++ {
		min[i] = time.Duration(5 * time.Second)
	}

	// Customize the Transport to have larger connection pool
	defaultRoundTripper := http.DefaultTransport
	defaultTransportPointer, ok := defaultRoundTripper.(*http.Transport)
	if !ok {
		log.Fatal("defaultRoundTripper not an *http.Transport")
	}
	defaultTransport := *defaultTransportPointer
	defaultTransport.MaxIdleConns = 1000
	defaultTransport.MaxIdleConnsPerHost = 1000

	CusClient = &http.Client{Transport: &defaultTransport}

	for cycle := 0; cycle < C; cycle++ {
		start := time.Now()
		r := 0
		er := 0
		var rl sync.Mutex
		for r < Q {
			wg.Add(1)
			r = r + 1
			go sendRequest(&er, &rl)
			/* if (time.Since(start)) > time.Second {
				log.Printf("Break after %v\n", r)
				break
			} */
			/* Uniform distribution of threads over time */
			if r%B == 0 {
				time.Sleep(time.Duration(W) * time.Microsecond)
			}
		}
		/* If we finished in less than a second then we
		 * have to wait until the second is elapsed */
		wg.Wait()
		log.Printf("Cycle %v acheived %v/%v throughput, it took: %v\n", cycle, er, Q, time.Since(start))
		// time.Sleep(time.Second - time.Since(start))
	}

	var avg time.Duration = 0
	total := 0
	for i := 0; i < 1000; i++ {
		if avgb[i] == true {
			avg = avg + avgs[i]/time.Duration(avgc[i])
			total = total + 1
		}
	}

	var gmin time.Duration = time.Duration(5 * time.Second)
	var gmax time.Duration

	for i := 0; i < 1000; i++ {
		if min[i] < gmin {
			gmin = min[i]
		}
		if max[i] > gmax {
			gmax = max[i]
		}
	}

	log.Printf("Average request duration: %v", avg/time.Duration(total))
	log.Printf("Min=%v Max=%v\n", gmin, gmax)
}
