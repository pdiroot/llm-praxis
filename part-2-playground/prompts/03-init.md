/init This is "whoami", a small Go web app that answers who called it: the host name, the IP addresses and the request headers. We build it here to learn Claude Code.

The code lives in "demo/whoami" on "https://gitlab.playground.localhost". It is one static binary, standard library only, and it runs as the systemd service "whoami".

Before each push, run `go fmt ./...`, `go vet ./...` and `go test ./...`.

Commit these instructions to the main branch and push them.
