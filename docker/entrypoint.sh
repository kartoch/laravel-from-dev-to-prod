#!/usr/bin/env bash

set -e

if [ "$1" = 'apache2-foreground' ]; then
    chown -R www-data:www-data /var/www/html/storage/
fi

exec "$@"
