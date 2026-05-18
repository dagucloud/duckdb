#!/bin/sh
set -eu

query=${query:-}
database=${database:-}
workdir=${workdir:-}
format=${format:-json}
readonly=${readonly:-false}

if [ -z "$query" ]; then
  echo "duckdb action: query is required" >&2
  exit 2
fi

case "$format" in
  json) mode_flag="-json" ;;
  csv) mode_flag="-csv" ;;
  table) mode_flag="-table" ;;
  markdown) mode_flag="-markdown" ;;
  line) mode_flag="-line" ;;
  list) mode_flag="-list" ;;
  column) mode_flag="-column" ;;
  *)
    echo "duckdb action: unsupported format '$format'" >&2
    exit 2
    ;;
esac

case "$readonly" in
  true|false) ;;
  *)
    echo "duckdb action: readonly must be true or false" >&2
    exit 2
    ;;
esac

if [ -n "$workdir" ]; then
  cd "$workdir"
fi

set -- -batch -bail -no-stdin "$mode_flag"

if [ "$readonly" = "true" ]; then
  set -- "$@" -readonly
fi

if [ -n "$database" ] && [ "$database" != ":memory:" ]; then
  set -- "$@" "$database"
fi

set -- "$@" -c "$query"

exec duckdb "$@"
