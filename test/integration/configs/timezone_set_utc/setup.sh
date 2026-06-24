#!/bin/sh
timedatectl show --property=Timezone --value 2>/dev/null > /tmp/configr_test_tz_orig2 || echo "America/New_York" > /tmp/configr_test_tz_orig2
