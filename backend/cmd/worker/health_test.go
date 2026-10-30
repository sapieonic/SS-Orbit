package main

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

type fakePinger struct{ err error }

func (f fakePinger) Ping(context.Context) error { return f.err }

func TestWorkerHealth(t *testing.T) {
	for _, tc := range []struct {
		name string
		db   error
		path string
		code int
	}{
		{"healthz ignores the DB", errors.New("down"), "/healthz", http.StatusOK},
		{"readyz ok", nil, "/readyz", http.StatusOK},
		{"readyz postgres down", errors.New("down"), "/readyz", http.StatusServiceUnavailable},
		{"unknown path", nil, "/metrics", http.StatusNotFound},
	} {
		t.Run(tc.name, func(t *testing.T) {
			rec := httptest.NewRecorder()
			healthHandler(fakePinger{tc.db}).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, tc.path, nil))
			assert.Equal(t, tc.code, rec.Code)
		})
	}
}

func TestProbe(t *testing.T) {
	ok := httptest.NewServer(healthHandler(fakePinger{}))
	defer ok.Close()
	if err := probe(strings.TrimPrefix(ok.URL, "http://")); err != nil {
		t.Fatalf("healthy worker: %v", err)
	}
	down := httptest.NewServer(healthHandler(fakePinger{err: errors.New("db down")}))
	defer down.Close()
	if err := probe(strings.TrimPrefix(down.URL, "http://")); err == nil {
		t.Fatal("unready worker must fail the probe")
	}
	if err := probe("127.0.0.1:1"); err == nil {
		t.Fatal("nothing listening must fail the probe")
	}
}
