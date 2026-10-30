package main

import (
	"bytes"
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
