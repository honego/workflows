#!/usr/bin/env bash

set -eEx

go mod download
go build -v -trimpath -o fakecd -ldflags="-s -w -buildid="

docker build --no-cache --progress=plain --tag honeok/fakecd:dev .
