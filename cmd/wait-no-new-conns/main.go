package main

import (
	"bufio"
	"flag"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"k8s.io/klog"
)

var maxWait = flag.Duration("max-wait", 30*time.Second, "the maximum duration to wait for")
var statusEndpoint = flag.String("status-endpoint", "", "nginx status endpoint")
var requestsThreshold = flag.Int("requests-threshold", 2, "")
var clientTimeout = flag.Duration("nginx-timeout", 1*time.Second, "timeout when checking nginx status endpoint")
var clientRetries = flag.Int("nginx-retries", 3, "number of retries if nginx is unreachable")

type checker struct {
	client    *http.Client
	endpoint  string
	threshold uint64

	lastConns uint64
}

func (c *checker) getAcceptedConns() (uint64, error) {
	resp, err := c.client.Get(c.endpoint)
	if err != nil {
		return 0, fmt.Errorf("error making HTTP request to %s: %w", c.endpoint, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("%s returned HTTP status %w", c.endpoint, resp.Status)
	}

	r := bufio.NewReader(resp.Body)

	// Skip first line (Active connections)
	_, err = r.ReadString('\n')
	if err != nil {
		return 0, err
	}

	// Server accepts handled requests
	_, err = r.ReadString('\n')
	if err != nil {
		return 0, err
	}

	line, err := r.ReadString('\n')
	if err != nil {
		return 0, err
	}

	data := strings.Fields(line)
	accepts, err := strconv.ParseUint(data[0], 10, 64)
	if err != nil {
		return 0, err
	}

	return accepts, nil
}

func (c *checker) hasNoNewConns() (bool, error) {
	conns, err := c.getAcceptedConns()
	if err != nil {
		return false, fmt.Errorf("can not get accepted conns: %w", err)
	}

	newConns := conns - c.lastConns

	if c.lastConns > 0 {
		klog.V(1).Infof("saw %d new conns (%d - %d)", newConns, conns, c.lastConns)
	}

	c.lastConns = conns

	if newConns <= c.threshold {
		return true, nil
	}

	return false, nil
}

func pollNginxStatus() int {
	defer klog.Flush()

	timeout := time.After(*maxWait)
	ticker := time.Tick(1 * time.Second)

	client := &http.Client{
		Timeout: *clientTimeout,
	}

	c := checker{
		client:    client,
		endpoint:  *statusEndpoint,
		threshold: uint64(*requestsThreshold),
	}

	retries := 0
	for {
		select {
		case <-ticker:
			canExit, err := c.hasNoNewConns()
			if err != nil {
				retries++
				klog.Errorf("can not check for new conns: %s, attempt %d/%d", err, retries, *clientRetries)
				if retries >= *clientRetries {
					return 1
				}
			}
			if canExit {
				klog.Infoln("no new conns, exiting")
				return 0
			}

		case <-timeout:
			klog.Warningln("timeout reached, exiting")
			return 1
		}
	}
}

func main() {
	klog.InitFlags(nil)
	flag.Parse()

	os.Exit(pollNginxStatus())
}
