#!/bin/sh
passwd="$(getent passwd testusr_mod)" || exit 1
echo "$passwd" | grep -q "/bin/sh" || exit 1
echo "$passwd" | grep -q "Modified User" || exit 1
