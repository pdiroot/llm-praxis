# sample-service

A small Go service for the LLM Praxis demo. It uses only the standard
library and keeps its data in memory.

## Run

    go run .

The service listens on port 8080.

## Endpoints

- `GET /health` returns the servce status. The body is `ok`.
- `GET /notes` lists the notes as JSON.
- `POST /notes` adds a note. The body is JSON, such as `{"text":"hello"}`.

## Test

    go vet ./... && go test ./...
