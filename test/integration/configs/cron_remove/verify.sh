#!/bin/sh
crontab -l 2>/dev/null | grep -q "configr_test_job_rm" && exit 1 || exit 0
