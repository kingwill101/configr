#!/bin/sh
locale -a | grep -qi "en_US.utf8" || exit 1
locale -a | grep -qi "C.utf8" || exit 1
