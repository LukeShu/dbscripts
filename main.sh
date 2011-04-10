#!/usr/bin/python
# -*- coding: utf-8 -*-

source config.sh

function mkrsexclude {
    error=1
    while ${error}; do
	run_python_cmd "filter.py"
	error=$?
    done
}

msg "Cleaning $tempdir"
stdnull "rm -r $tempdir/* "

msg "Generating exclude list for rsync"
mkrsexclude

msg "Syncing repo files without delete"
${rsync_update_command} --exclude-from=${rsync_blacklist} ${mirror}${mirropath}/