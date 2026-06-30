#!/bin/sh
hostname > /tmp/configr_test_hostname_orig 2>/dev/null || echo "localhost" > /tmp/configr_test_hostname_orig
