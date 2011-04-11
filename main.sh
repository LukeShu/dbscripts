#!/bin/bash
# -*- coding: utf-8 -*-

source config.sh

function mkrsexclude {
    local error=1
    while ${error}; do
	run_python_cmd "filter.py"
	error=$?
    done
}

msg "Cleaning $tempdir"
stdnull "rm -r $tempdir/* "

msg "Generating exclude list for rsync"
mkrsexclude

msg "Syncing repos without delete"
# rsync_update_command does not sync db or abs
${rsync_update_command} --exclude-from=${rsync_blacklist} \
    ${mirror}${mirropath}/{$(echo ${repo_list} | tr ':' ','),\
    $(echo ${dir_list} | tr ':' ',')} ${repodir}

msg "Syncing each repo and cleaning"
msg2 "Remove pending files"
stdnull "rm -rf ${pending}*"
for repo in $(echo ${repo_list} | tr ':' ' '); do
    for arch in $(echo ${arch_list} | tr ':' ' '); do
	msg2 "Syncing ${repo} ${arch}"
	${rsync_post_command} --exclude-from=${rsync_blacklist} \
	    ${mirror}${mirropath}/${repo} ${repodir}/${repo}
	msg2 "Making pending list for ${repo} ${arch}"
	run_python_cmd "mkpending.py -r ${repo} -b ${repodir}/${repo}/os/${arch}"
	msg2 "Cleaning ${repo} ${arch}"
	run_python_cmd "clean_repo.py -b ${repodir}/${repo}/os/${arch}/${repo}.db.tar.gz -d ${repodir}/${repo}/os/${arch}/"
    done
done

msg "Checking licenses"
get_license.sh
