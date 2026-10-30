package main

import (
	"encoding/json"
	"net/http"
	"sync"
)

type note struct {
	Text string `json:"text"`
}

const maxNotes = 100

var (
	mu    sync.Mutex
	notes = []note{}
)

func init() {
	mux.HandleFunc("GET /notes", listNotes)
	mux.HandleFunc("POST /notes", addNote)
}

func listNotes(w http.ResponseWriter, _ *http.Request) {
	mu.Lock()
	defer mu.Unlock()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(notes)
}

func addNote(w http.ResponseWriter, r *http.Request) {
	var n note
	if err := json.NewDecoder(r.Body).Decode(&n); err != nil || n.Text == "" {
		http.Error(w, "need a JSON body with a text", http.StatusBadRequest)
		return
	}
	mu.Lock()
	defer mu.Unlock()
	if len(notes) >= maxNotes {
		http.Error(w, "too many notes", http.StatusTooManyRequests)
		return
	}
	notes = append(notes, n)
	w.WriteHeader(http.StatusCreated)
}
