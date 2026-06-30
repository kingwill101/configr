#!/usr/bin/env bash
set -euo pipefail

test -f build/configr_cross_platform_sweep.txt
grep -q "cross-platform sweep" build/configr_cross_platform_sweep.txt
