#!/bin/sh
getent group testgrp_rm 2>/dev/null && exit 1 || exit 0
