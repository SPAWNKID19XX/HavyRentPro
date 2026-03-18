#!/bin/bash

set -e

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL..."
while ! nc -z $DB_HOST $DB_PORT; do
  sleep 1
done
echo "PostgreSQL is ready!"

# Run Django migrations
echo "Running Django migrations..."
python manage.py migrate

# Start Daphne server
echo "Starting Daphne server..."
daphne -b 0.0.0.0 -p 8000 config.asgi:application
