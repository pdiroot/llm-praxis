package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestPlainText(t *testing.T) {
	commit = "abc1234"
	req := httptest.NewRequest("GET", "/", nil)
	req.Header.Set("X-Test", "yes")
	rec := httptest.NewRecorder()
	handler().ServeHTTP(rec, req)
	body := rec.Body.String()
	for _, want := range []string{"Hostname: ", "X-Test: yes", "Commit: abc1234\n"} {
		if !strings.Contains(body, want) {
			t.Errorf("answer lacks %q:\n%s", want, body)
		}
	}
}

func TestAccessLogHasNoHeaders(t *testing.T) {
	var buf bytes.Buffer
	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set("Authorization", "Bearer secret")
	logged(&buf, http.NotFoundHandler()).ServeHTTP(httptest.NewRecorder(), req)
	line := buf.String()
	if strings.Contains(line, "secret") || !strings.Contains(line, `GET "/x" 404`) {
		t.Errorf("unexpected log line: %q", line)
	}
}

func TestJSON(t *testing.T) {
	commit = "abc1234"
	req := httptest.NewRequest("GET", "/?format=json", nil)
	req.Header.Set("X-Test", "yes")
	rec := httptest.NewRecorder()
	handler().ServeHTTP(rec, req)
	if ct := rec.Header().Get("Content-Type"); ct != "application/json" {
		t.Errorf("Content-Type = %q", ct)
	}
	var got info
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatalf("not JSON: %v\n%s", err, rec.Body)
	}
	if got.Hostname == "" || got.Commit != "abc1234" || got.Headers.Get("X-Test") != "yes" {
		t.Errorf("unexpected answer: %+v", got)
	}
}
