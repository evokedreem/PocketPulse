#!/bin/sh
set -eu

if [ ! -e /app/node_modules ]; then
  ln -s /opt/pocketpulse/node_modules /app/node_modules
fi

exec "$@"
