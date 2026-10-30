package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"time"
)

// pinger is the part of *pgxpool.Pool the health check needs.
type pinger interface {
	Ping(ctx context.Context) error
}

// healthHandler serves the worker's container health checks (ECS):
// /healthz is 200 while the process runs; /readyz is 503 when Postgres, which
// River needs for every job, is unreachable. The worker does not use Redis
// directly, so it is not checked.
func healthHandler(db pinger) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeHealth(w, http.StatusOK, map[string]any{"status": "ok"})
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := db.Ping(ctx); err != nil {
			writeHealth(w, http.StatusServiceUnavailable, map[string]any{
				"status": "unavailable", "checks": map[string]string{"postgres": "error: " + err.Error()}})
			return
		}
		writeHealth(w, http.StatusOK, map[string]any{"status": "ok", "checks": map[string]string{"postgres": "ok"}})
	})
	return mux
}

func writeHealth(w http.ResponseWriter, code int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(body)
}

// newHealthServer returns the worker's health server on addr.
func newHealthServer(addr string, db pinger) *http.Server {
	return &http.Server{
		Addr:              addr,
		Handler:           healthHandler(db),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
	}
}

// probe calls /readyz on the worker listening at addr (":8081" when empty) and
// fails unless it answers 200. It runs as `worker -healthcheck` inside the
// container, where there is no shell or curl.
func probe(addr string) error {
	if addr == "" {
		addr = ":8081"
	}
	host, port, err := net.SplitHostPort(addr)
	if err != nil {
		return fmt.Errorf("healthcheck: bad WORKER_HEALTH_ADDR %q: %w", addr, err)
	}
	if host == "" || host == "0.0.0.0" || host == "::" {
		host = "127.0.0.1"
	}
	client := http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get("http://" + net.JoinHostPort(host, port) + "/readyz")
	if err != nil {
		return fmt.Errorf("healthcheck: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("healthcheck: /readyz returned %d", resp.StatusCode)
	}
	return nil
}
