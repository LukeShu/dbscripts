#!/bin/sh
# -*- coding: utf-8 -*-
source local_config

function run_python_cmd {
    env \
	mirror=${mirror} \
	mirrorpath=${mirrorpath} \
	logname=${logname} \
	tempdir=${tempdir} \
	archdb=${archdb} \
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