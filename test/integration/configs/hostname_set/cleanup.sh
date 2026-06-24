#!/bin/sh
if [ -f /tmp/configr_test_hostname_orig ]; then
  orig="$(cat /tmp/configr_test_hostname_orig)"
  hostname "$orig" 2>/dev/null || true
  echo "$orig" > /etc/hostname 2>/dev/null || true
  rm -f /tmp/configr_test_hostname_orig
fi
