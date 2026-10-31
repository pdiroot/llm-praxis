package main

import (
	"fmt"
	"net/http"
)

const version = "0.2.0"

func init() {
	http.HandleFunc("/version", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintln(w, version)
	})
}
