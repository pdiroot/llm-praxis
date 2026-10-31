// Command hello-world says hello over HTTP.
package main

import (
	"fmt"
	"log"
	"net/http"
)

func hello(w http.ResponseWriter, r *http.Request) {
	name := r.URL.Query().Get("name")
	if name == "" {
		name = "world"
	}

	fmt.Fprintf(w, "Bonjour, %s!\n", name)
}

func main() {
	http.HandleFunc("/", hello)
	log.Fatal(http.ListenAndServe(":8080", nil))
}
