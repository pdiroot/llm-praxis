package main

import (
	"net/http/httptest"
	"testing"
)

func TestHelloName(t *testing.T) {
	rec := httptest.NewRecorder()
	hello(rec, httptest.NewRequest("GET", "/?name=Ada", nil))

	if got := rec.Body.String(); got != "Bonjour, Ada!\n" {
		t.Fatalf("body = %q", got)
	}
}
