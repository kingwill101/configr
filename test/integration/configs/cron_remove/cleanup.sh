#!/bin/sh
crontab -l 2>/dev/null | grep -v "configr_test_job_rm" | crontab - 2>/dev/null || true
