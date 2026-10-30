package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
)

// commit is set at build time: -ldflags "-X main.commit=<sha>".
var commit = "dev"

const (
	logPath = "/var/log/whoami/access.log"
	pidPath = "/run/whoami/whoami.pid"
)

type info struct {
	Hostname string      `json:"hostname"`
	IPs      []string    `json:"ips"`
	Headers  http.Header `json:"headers"`
	Commit   string      `json:"commit"`
}

func collect(r *http.Request) info {
	host, _ := os.Hostname()
	var ips []string
	addrs, _ := net.InterfaceAddrs()
	for _, a := range addrs {
		ips = append(ips, a.String())
	}
	h := r.Header.Clone()
	h.Set("Host", r.Host) // net/http moves Host out of r.Header
	return info{Hostname: host, IPs: ips, Headers: h, Commit: commit}
}

func writeText(w io.Writer, in info) {
	fmt.Fprintf(w, "Hostname: %s\n", in.Hostname)
	for _, ip := range in.IPs {
		fmt.Fprintf(w, "IP: %s\n", ip)
	}
	keys := make([]string, 0, len(in.Headers))
	for k := range in.Headers {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		fmt.Fprintf(w, "%s: %s\n", k, strings.Join(in.Headers[k], ", "))
	}
	fmt.Fprintf(w, "Commit: %s\n", in.Commit)
}

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (s *statusWriter) WriteHeader(c int) {
	s.status = c
	s.ResponseWriter.WriteHeader(c)
}

// logged writes one line per request. It logs the time, the remote address,
// the method, the path and the status, never a header: Authorization and
// Cookie would end up in the file. strconv.Quote keeps a crafted path on
// one line.
func logged(out io.Writer, next http.Handler) http.Handler {
	l := log.New(out, "", log.LstdFlags)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(sw, r)
		l.Printf("%s %s %s %d", r.RemoteAddr, r.Method, strconv.Quote(r.URL.Path), sw.status)
	})
}

func handler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		in := collect(r)
		if r.URL.Query().Get("format") == "json" {
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(in)
			return
		}
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		writeText(w, in)
	})
}

func main() {
	f, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o640)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()
	if err := os.WriteFile(pidPath, []byte(strconv.Itoa(os.Getpid())+"\n"), 0o644); err != nil {
		log.Fatal(err)
	}
	log.Fatal(http.ListenAndServe(":80", logged(f, handler())))
}
