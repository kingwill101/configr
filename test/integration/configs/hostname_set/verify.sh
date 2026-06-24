#!/bin/sh
current="$(hostname)"
[ "$current" = "configr-test-host" ] || exit 1
