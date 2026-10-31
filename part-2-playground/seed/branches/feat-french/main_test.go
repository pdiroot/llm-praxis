package main

import (
	"net/http/httptest"
	"testing"
)

func TestHello(t *testing.T) {
	rec := httptest.NewRecorder()
	hello(rec, httptest.NewRequest("GET", "/", nil))

	if got := rec.Body.String(); got != "Bonjour, world!\n" {
		t.Fatalf("body = %q", got)
	}
}
