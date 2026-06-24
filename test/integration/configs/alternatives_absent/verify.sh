#!/bin/sh
update-alternatives --display editor 2>/dev/null | grep -q "/bin/nano" && exit 1 || exit 0
