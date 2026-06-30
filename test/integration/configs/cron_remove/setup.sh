#!/bin/sh
(crontab -l 2>/dev/null; echo "0 5 * * * /bin/true #configr_test_job_rm") | crontab - 2>/dev/null || true
