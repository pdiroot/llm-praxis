/plan The first version of the app. It should answer each request in plain text with the host name, the IP addresses and the request headers, and write an access log to a file. Build it on the branch "feat/whoami".

Add a GitLab pipeline with the image "golang:1.27.3" and three stages. "test" runs the unit tests. "build" builds the binary and keeps it as an artifact. "integration" starts that binary and checks its answer with `curl`. No deployment yet.
