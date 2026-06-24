#!/bin/sh
[ "$(sysctl -n net.ipv4.ip_forward)" = "1" ] || exit 1
