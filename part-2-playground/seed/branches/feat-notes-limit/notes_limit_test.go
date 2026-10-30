package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestNotesLimit(t *testing.T) {
	mu.Lock()
	notes = []note{}
	mu.Unlock()

	for i := 0; i <= maxNotes; i++ {
		rec := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodPost, "/notes", strings.NewReader(`{"text":"x"}`))
		mux.ServeHTTP(rec, req)
		want := http.StatusCreated
		if i == maxNotes {
			want = http.StatusTooManyRequests
		}
		if rec.Code != want {
			t.Fatalf("note %d: got %d, want %d", i, rec.Code, want)
		}
	}
}
