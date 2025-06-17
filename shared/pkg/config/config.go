package config

import (
	"log"
	"os"
)

type ServiceConfig struct {
	Port        string
	ServiceName string
}

func LoadServiceConfig(serviceName, defaultPort string) *ServiceConfig {
	port := os.Getenv(serviceName + "_PORT")
	if port == "" {
		port = defaultPort
	}

	return &ServiceConfig{
		Port:        port,
		ServiceName: serviceName,
	}
}

func (c *ServiceConfig) LogStartup() {
	log.Printf("%s service starting on port %s", c.ServiceName, c.Port)
}