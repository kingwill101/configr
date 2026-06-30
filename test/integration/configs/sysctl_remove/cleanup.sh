#!/bin/sh
rm -f /tmp/configr_sysctl_test_rm.conf
sysctl -w net.ipv4.ip_forward=0 2>/dev/null || true
