#!/usr/bin/python
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
    ${mirror}${mirropath}/{$(echo ${repo_list} | tr ':' ',')} ${repodir}

msg "Syncing each repo and cleaning"
for repo in $(echo ${repo_list} | tr ':' ' '); do
    msg2 "Syncing ${repo}"
    ${rsync_post_command} --exclude-from=${rsync_blacklist} \
	${mirror}${mirropath}/${repo} ${repodir}/${repo}
    msg2 "Cleaning ${repo}"
    clean-repo.py -d ${repodir}/${repo} \
	-b ${repodir}/${repo}/${repo}.db.tar.gz
    msg2 "Making pending list for ${repo}"
    run_python_cmd "mkpending.py -r ${repo} -d ${repodir}/${repo}"
done
