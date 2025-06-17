package main

import (
	"log"
	"net/http"

	"github.com/wguilherme/golang-12-factor-app-microservices/shared/pkg/config"
	"github.com/wguilherme/golang-12-factor-app-microservices/shared/pkg/health"
)

func main() {
	cfg := config.LoadServiceConfig("WORKER_POST", "8081")

	http.HandleFunc("/health/live", health.LivenessHandler("worker_post"))
	http.HandleFunc("/health/ready", health.ReadinessHandler("worker_post"))

	cfg.LogStartup()
	if err := http.ListenAndServe(":"+cfg.Port, nil); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
