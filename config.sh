#!/bin/sh
# -*- coding: utf-8 -*-
source local_config

# Rsync commands
rsync_update_command="rsync -av --delay-updates --exclude='*.{abs|db}.tar.*' "
rsync_post_command="rsync -av --delete --exclude='*.abs.tar.*' "

function run_python_cmd {
    env \
	mirror=${mirror} \
	mirrorpath=${mirrorpath} \
	logname=${logname} \
	tempdir=${tempdir} \
	archdb=${archdb} \
	docs_dir=${docs_dir} \
	repodir=${repodir} \
	blacklist=${blacklist} \
	whitelist=${whitelist} \
	pending=${pending} \
	rsync_blacklist=${rsync_blacklist} \
	repo_list=${repo_list} \
	dir_list=${dir_list} \
	arch_list=${arch_list} \
	other=${other} \
	output=${output} \
	debug=${debug} \
	$1
}

source libremessages