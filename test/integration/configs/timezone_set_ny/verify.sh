#!/bin/sh
# Check /etc/localtime symlink directly -- timedatectl requires systemd
# which isn't available inside Docker containers.
localtime="$(readlink /etc/localtime 2>/dev/null)" || exit 1
[ "$localtime" = "/usr/share/zoneinfo/America/New_York" ] || exit 1
