#!/bin/sh
set -e

if ! getent group syslog-flow >/dev/null 2>&1; then
    addgroup --system syslog-flow
fi
if ! getent passwd syslog-flow >/dev/null 2>&1; then
    adduser --system --ingroup syslog-flow --no-create-home --shell /usr/sbin/nologin syslog-flow
fi

mkdir -p /var/log/syslog-flow /var/lib/syslog-flow
chown -R syslog-flow:syslog-flow /var/log/syslog-flow /var/lib/syslog-flow

if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
fi

exit 0
