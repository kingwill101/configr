#!/bin/sh
update-alternatives --display editor 2>/dev/null | grep -q "/bin/nano" || exit 1
# readlink -f resolves through ALL symlinks (e.g. /bin/nano -> /usr/bin/nano),
# so accept either /bin/nano or /usr/bin/nano as the final target.
linkpath="$(readlink -f /usr/bin/editor 2>/dev/null || readlink /etc/alternatives/editor 2>/dev/null)"
[ "$linkpath" = "/bin/nano" -o "$linkpath" = "/usr/bin/nano" ] || exit 1
