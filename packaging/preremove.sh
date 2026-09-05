#!/bin/sh
set -e

if command -v systemctl >/dev/null 2>&1; then
    systemctl stop syslog-flow.service >/dev/null 2>&1 || true
    systemctl disable syslog-flow.service >/dev/null 2>&1 || true
fi

exit 0
