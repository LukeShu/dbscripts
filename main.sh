#!/bin/bash
# -*- coding: utf-8 -*-

source ./config
source ./local_config
source ./libremessages

for repo in ${PKGREPOS[@]}; do
    for arch in ${ARCHES[@]} 'any'; do
	msg "Syncing ${repo} ${arch}"
	filter.py -r "${rsync_blacklist}" -k "${blacklist}" -c \
	    \"${rsync_list_command}\ \
	    ${mirror}${mirrorpath}/${repo}/os/${arch}\ \
	    ${repodir}/${repo}/\"
	find ${repodir}/${repo} -name *${PKGEXT} -print \
	    > ${rsync_not_needed}
	${rsync_update_command} \
	    ${mirror}${mirrorpath}/${repo}/os/${arch} \
	    ${repodir}/${repo} \
	    --exclude-from=${rsync_blacklist} \
	    --exclude-from=${rsync_not_needed}
    done
    for arch in ${ARCHES[@]}; do
	if [ -r ${repodir}/${repo}/os/${arch}/${repo}${DBEXT} ]; then
	    clean_repo.py -k ${blacklist} -w ${whitelist} \
		-p ${docs_dir}/pending-${repo} \
		-b ${repodir}/${repo}/${repo}${DBEXT}
	fi
	clean_repo.py -k ${blacklist} -d ${repodir}/${repo}
done

db-update
ftpdir-cleanup

get_license.sh
