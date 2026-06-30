#!/bin/sh
crontab -l 2>/dev/null | grep -v "configr_test_job_disabled" | crontab - 2>/dev/null || true
