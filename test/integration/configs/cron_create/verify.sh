#!/bin/sh
crontab -l 2>/dev/null | grep -q "configr_test_job" || exit 1
crontab -l 2>/dev/null | grep -q "0 5" || exit 1
crontab -l 2>/dev/null | grep -q "/bin/true" || exit 1
