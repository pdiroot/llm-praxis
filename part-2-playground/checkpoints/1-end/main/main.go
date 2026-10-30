package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

// commit is set at build time: -ldflags "-X main.commit=<sha>".
var commit = "dev"

// dir returns the directory systemd sets in env (LogsDirectory= and
// RuntimeDirectory=), or a folder in the temp dir when the app runs by hand.
func dir(env string) string {
	if v := os.Getenv(env); v != "" {
		return v
	}
	return filepath.Join(os.TempDir(), "whoami")
}

type info struct {
	Hostname string
	IPs      []string
	Headers  http.Header
	Commit   string
}

func collect(r *http.Request) info {
	host, _ := os.Hostname()
	var ips []string
	addrs, _ := net.InterfaceAddrs()
	for _, a := range addrs {
		if n, ok := a.(*net.IPNet); ok {
			ips = append(ips, n.IP.String())
		}
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
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		writeText(w, collect(r))
	})
}

func main() {
	addr := flag.String("addr", ":80", "listen address")
	flag.Parse()
	logDir, runDir := dir("LOGS_DIRECTORY"), dir("RUNTIME_DIRECTORY")
	for _, d := range []string{logDir, runDir} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			log.Fatal(err)
		}
	}
	f, err := os.OpenFile(filepath.Join(logDir, "access.log"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o640)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()
	pid := []byte(strconv.Itoa(os.Getpid()) + "\n")
	if err := os.WriteFile(filepath.Join(runDir, "whoami.pid"), pid, 0o644); err != nil {
		log.Fatal(err)
	}
	log.Fatal((&http.Server{Addr: *addr, Handler: logged(f, handler()), ReadHeaderTimeout: 5 * time.Second}).ListenAndServe())
}
