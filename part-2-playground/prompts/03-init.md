/init This is "whoami", a small Go web app that answers who called it: the host name, the IP addresses and the request headers.

The code lives in "demo/whoami" on GitLab: "origin" is "ssh://git@gitlab.playground.localhost:2222/demo/whoami.git", and the web page is "https://gitlab.playground.localhost/demo/whoami". It is one static binary, standard library only, and it runs as the systemd service "whoami".

Before each push, run `go fmt ./...`, `go vet ./...` and `go test ./...`. Do not push to "origin" until I have reviewed the code and told you to push.

Add ".env" to ".gitignore". Commit these instructions to the "main" branch.
