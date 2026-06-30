#!/bin/sh
if [ -f /tmp/configr_test_tz_orig ]; then
  tz="$(cat /tmp/configr_test_tz_orig)"
  timedatectl set-timezone "$tz" 2>/dev/null || true
  rm -f /tmp/configr_test_tz_orig
fi
