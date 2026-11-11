#!/bin/sh
# Container entrypoint: makes the writable data directories usable by the unprivileged
# "app" user (bind mounts / platform volumes are usually created root-owned), then drops
# privileges and runs the server as that user. If the container is started with a non-root
# user already, it just runs the command.
set -e

DATA_DIRS="/app/backend/uploads /app/reports /app/backend/.cache"

if [ "$(id -u)" = "0" ]; then
    APP_UID="$(id -u app)"
    for d in $DATA_DIRS; do
        mkdir -p "$d"
        # Only re-own a directory tree when its top level is not already owned by app
        # (avoids a slow recursive chown of large upload volumes on every start).
        if [ "$(stat -c %u "$d")" != "$APP_UID" ]; then
            chown -R app:app "$d" || echo "warning: could not chown $d" >&2
        fi
    done
    exec gosu app "$@"
fi

exec "$@"
