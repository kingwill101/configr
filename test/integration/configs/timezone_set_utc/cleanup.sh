#!/bin/sh
if [ -f /tmp/configr_test_tz_orig2 ]; then
  tz="$(cat /tmp/configr_test_tz_orig2)"
  timedatectl set-timezone "$tz" 2>/dev/null || true
  rm -f /tmp/configr_test_tz_orig2
fi
