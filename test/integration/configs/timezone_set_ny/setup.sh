#!/bin/sh
timedatectl show --property=Timezone --value 2>/dev/null > /tmp/configr_test_tz_orig || echo "UTC" > /tmp/configr_test_tz_orig
