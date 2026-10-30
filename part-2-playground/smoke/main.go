package main

import (
	"fmt"
	"net/http"
	"os"
)

var commit = "dev"

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		h, _ := os.Hostname()
		fmt.Fprintf(w, "Hostname: %s\nCommit: %s\n", h, commit)
	})
	_ = http.ListenAndServe(":80", nil)
}
