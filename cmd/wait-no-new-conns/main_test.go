package main

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

type mockStatus struct {
	hits    int
	outputs []string
}

func (mock *mockStatus) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if mock.hits >= len(mock.outputs) {
		w.Write([]byte("Should not happen"))
		return
	}

	fmt.Fprintf(w, `Active connections: 585
	server accepts handled requests
	 %s 85340 35085
	Reading: 4 Writing: 135 Waiting: 446`, mock.outputs[mock.hits])

	mock.hits++
}

func TestGetAcceptedConns(t *testing.T) {
	// Start a local HTTP server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`Active connections: 585
		server accepts handled requests
		 85340 85340 35085
		Reading: 4 Writing: 135 Waiting: 446`))
	}))
	// Close the server when test finishes
	defer server.Close()

	c := &checker{
		client:   server.Client(),
		endpoint: server.URL,
	}

	conns, err := c.getAcceptedConns()
	if err != nil {
		t.Fatalf("got an error with getAcceptedConns %s", err)
	}

	if conns != 85340 {
		t.Fatalf("got %v, expected 85340", conns)
	}
}

func TestHasNoNewConns(t *testing.T) {
	type testCase struct {
		threshold uint64
		hits      int
		outputs   []string
	}
	tests := []testCase{
		{1, 5, []string{"100", "200", "250", "255", "255"}},
		{10, 7, []string{"100", "200", "250", "270", "290", "305", "315"}},
	}

	for _, tc := range tests {
		fake := &mockStatus{
			outputs: tc.outputs,
		}

		server := httptest.NewServer(fake)
		// Close the server when test finishes
		defer server.Close()

		c := &checker{
			client:    server.Client(),
			endpoint:  server.URL,
			threshold: tc.threshold,
		}

		hits := 0
		for {
			hasNewConns, err := c.hasNoNewConns()
			if err != nil {
				t.Fatal(err)
			}

			hits++
			if hasNewConns {
				break
			}
		}

		if hits != tc.hits {
			t.Fatalf("hasNoNewConns returned true after %v hits, expected %v", hits, tc.hits)
		}
	}

}
