#!/bin/sh
if [ -f /tmp/configr_sysctl_test_rm.conf ]; then
  grep -q "net.ipv4.ip_forward" /tmp/configr_sysctl_test_rm.conf && exit 1 || exit 0
fi
exit 0
