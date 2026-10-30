// Command sample-service is a small HTTP service for the demo.
package main

import (
	"log"
	"net/http"
)

// mux holds the routes. Each handler file registers its own route.
var mux = http.NewServeMux()

func main() {
	log.Fatal(http.ListenAndServe(":8080", mux))
}
