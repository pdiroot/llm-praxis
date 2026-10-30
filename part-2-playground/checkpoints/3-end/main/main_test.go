package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
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
	// encoding/json matches field names case-insensitively, so check the raw keys.
	var keys map[string]json.RawMessage
	if err := json.Unmarshal(rec.Body.Bytes(), &keys); err != nil {
		t.Fatalf("not JSON: %v\n%s", err, rec.Body)
	}
	for _, k := range []string{"hostname", "ips", "headers", "commit"} {
		if _, ok := keys[k]; !ok {
			t.Errorf("key %q missing in %s", k, rec.Body)
		}
	}
	if len(keys) != 4 {
		t.Errorf("want 4 keys, got %d", len(keys))
	}
	var got info
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	if got.Hostname == "" || got.Commit != "abc1234" || got.Headers.Get("X-Test") != "yes" {
		t.Errorf("unexpected answer: %+v", got)
	}
}

func TestHTMLForBrowser(t *testing.T) {
	commit = "abc1234"
	req := httptest.NewRequest("GET", "/", nil)
	req.Header.Set("Accept", "text/html,application/xhtml+xml,*/*;q=0.8")
	rec := httptest.NewRecorder()
	handler().ServeHTTP(rec, req)
	body := rec.Body.String()
	if ct := rec.Header().Get("Content-Type"); !strings.HasPrefix(ct, "text/html") {
		t.Errorf("Content-Type = %q", ct)
	}
	for _, want := range []string{"<!doctype html>", "Commit: <code>abc1234</code>", "Accept"} {
		if !strings.Contains(body, want) {
			t.Errorf("page lacks %q", want)
		}
	}
}

func TestJSONBeatsBrowserAccept(t *testing.T) {
	req := httptest.NewRequest("GET", "/?format=json", nil)
	req.Header.Set("Accept", "text/html")
	rec := httptest.NewRecorder()
	handler().ServeHTTP(rec, req)
	if ct := rec.Header().Get("Content-Type"); ct != "application/json" {
		t.Errorf("Content-Type = %q", ct)
	}
}

func TestDirChoice(t *testing.T) {
	t.Setenv("LOGS_DIRECTORY", "/var/log/x")
	if got := dir("LOGS_DIRECTORY"); got != "/var/log/x" {
		t.Errorf("env set: got %q", got)
	}
	t.Setenv("LOGS_DIRECTORY", "")
	if got := dir("LOGS_DIRECTORY"); got != filepath.Join(os.TempDir(), "whoami") {
		t.Errorf("env unset: got %q", got)
	}
}

func TestHTMLEscapesHeaders(t *testing.T) {
	req := httptest.NewRequest("GET", "/", nil)
	req.Header.Set("Accept", "text/html")
	req.Header.Set("X-Evil", "<script>alert(1)</script>")
	rec := httptest.NewRecorder()
	handler().ServeHTTP(rec, req)
	body := rec.Body.String()
	if strings.Contains(body, "<script>") || !strings.Contains(body, "&lt;script&gt;") {
		t.Errorf("header value not escaped:\n%s", body)
	}
	if rec.Header().Get("Vary") != "Accept" {
		t.Errorf("Vary = %q", rec.Header().Get("Vary"))
	}
}
