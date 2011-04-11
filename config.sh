#!/bin/sh
# -*- coding: utf-8 -*-

# Mirror options
mirror="mirrors.eu.kernel.org"
mirrorpath="::mirrors/archlinux"

# Directories
## Optionals
paraboladir=~/parabolagnulinux.org
logtime=$(date -u +%Y%m%d-%H:%M)
## Must be defined
logname=${paraboladir}/${logtime}-repo-maintainer.log
tempdir=~/tmp/
docs_dir=${paraboladir}/docs
repodir=${paraboladir}/repo
# End Directories

# Files
blacklist=${docs_dir}/blacklist.txt
whitelist=${docs_dir}/whitelist.txt
pending=${docs_dir}/pending
rsync_blacklist=${docs_dir}/rsyncBlacklist

# Repos, arches, and dirs for repo
repo_list="core:extra:community:testing:community-testing:multilib"
dir_list="pool"
arch_list="i686:x86_64"
other="any"

# Output options
output="True"
debug="False"

# Rsync commands
rsync_update_command="rsync -av --delay-updates --exclude='*.{abs|db}.tar.*' "
rsync_post_command="rsync -av --delete --exclude='*.abs.tar.*' "

function run_python_cmd {
    env \
	mirror=${mirror} \
	mirrorpath=${mirrorpath} \
	logname=${logname} \
	tempdir=${tempdir} \
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