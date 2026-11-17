#!/usr/bin/env bash
# Generate prompts.js from ../prompts/*.md, so the deck works from file://.
# Usage: build.sh [output-file]
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
out=${1:-$here/prompts.js}
tmp=$out

# Write a regular file through a temporary file, so a failed build keeps the old one.
[[ $out == /dev/* ]] || tmp=$(mktemp "$out.XXXXXX")

{
  printf 'window.PROMPTS = '
  for file in "$here"/../prompts/*.md; do
    jq -Rs --arg id "$(basename "$file" .md)" '{($id): .}' "$file"
  done | jq -s 'add'
  printf ';\n'
} >"$tmp"

[[ $tmp == "$out" ]] || { chmod 644 "$tmp" && mv "$tmp" "$out"; }
