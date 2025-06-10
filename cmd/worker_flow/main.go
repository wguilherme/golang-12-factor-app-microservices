package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

type HealthResponse struct {
	Status    string `json:"status"`
	Service   string `json:"service"`
	Timestamp string `json:"timestamp"`
}

func main() {
	port := os.Getenv("WORKER_FLOW_PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/health/live", livenessHandler)
	http.HandleFunc("/health/ready", readinessHandler)

	log.Printf("Worker Flow service starting on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}

func livenessHandler(w http.ResponseWriter, r *http.Request) {
	response := HealthResponse{
		Status:    "UP",
		Service:   "worker_flow",
		Timestamp: time.Now().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

func readinessHandler(w http.ResponseWriter, r *http.Request) {

	response := HealthResponse{
		Status:    "READY",
		Service:   "worker_flow",
		Timestamp: time.Now().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}
