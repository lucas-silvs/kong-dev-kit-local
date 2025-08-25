#!/bin/bash

echo "Waiting for PostgreSQL to be ready..."

# Wait for PostgreSQL to be ready with a simple sleep
echo "Sleeping for 10 seconds to ensure PostgreSQL is ready..."
sleep 10

echo "PostgreSQL should be ready! Starting Kong migrations..."

# Run Kong migrations
kong migrations bootstrap

echo "Starting Kong..."
kong start
