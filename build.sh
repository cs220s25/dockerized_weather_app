#!/bin/bash

# Build both containers.  If there are no changes, this will be fast.
docker build -t collector collector
docker build -t server server

# It is an error to make the network if it already exists.
if ! docker network inspect weather > /dev/null 2>&1; then
  docker network create weather
else
  echo "Network 'weather' already exists."
fi
