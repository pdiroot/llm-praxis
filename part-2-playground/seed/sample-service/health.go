package main

import (
	"fmt"
	"net/http"
)

func init() {
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintln(w, "ok")
	})
}
