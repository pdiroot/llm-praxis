package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestNotes(t *testing.T) {
	mu.Lock()
	notes = []note{}
	mu.Unlock()

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/notes", strings.NewReader(`{"text":"hello"}`))
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("post: got %d", rec.Code)
	}

	rec = httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/notes", nil))
	if !strings.Contains(rec.Body.String(), "hello") {
		t.Fatalf("list: got %q", rec.Body.String())
	}
}
