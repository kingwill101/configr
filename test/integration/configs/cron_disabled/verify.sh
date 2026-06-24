#!/bin/sh
crontab -l 2>/dev/null | grep -q "configr_test_job_disabled" || exit 1
crontab -l 2>/dev/null | grep -q "^#" || exit 1
