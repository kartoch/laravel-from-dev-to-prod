#!/usr/bin/env bash

set -e

if [ "$1" = 'npm' ]; then
    npm install
    exec "$@"
fi

exec "$@"
