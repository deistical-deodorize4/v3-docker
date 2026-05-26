#!/bin/sh
apk add --no-cache unbound drill ca-certificates >/dev/null 2>&1
mkdir -p /var/lib/unbound
unbound-anchor -a /var/lib/unbound/root.key 2>/dev/null || true
# unbound drops privileges to the 'unbound' user; root.key must be writable by that user
chown -R unbound:unbound /var/lib/unbound 2>/dev/null || true
exec unbound -d
