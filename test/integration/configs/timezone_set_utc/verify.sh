#!/bin/sh
# Check /etc/localtime symlink directly -- timedatectl requires systemd
# which isn't available inside Docker containers.
localtime="$(readlink /etc/localtime 2>/dev/null)" || exit 1
# Accept both /usr/share/zoneinfo/UTC and /usr/share/zoneinfo/Etc/UTC,
# since the fallback ln -sf uses the literal timezone name.
[ "$localtime" = "/usr/share/zoneinfo/Etc/UTC" ] ||
[ "$localtime" = "/usr/share/zoneinfo/UTC" ] || exit 1
