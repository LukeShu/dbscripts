#!/bin/bash

curdir="$(dirname "$(readlink -e "$0")")"
. "${curdir}/../lib/common.inc"

testSourceballs() {
	local pkgs=('pkg-simple-a' 'pkg-simple-b' 'pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			releasePackage extra "${pkgbase}" "${arch}"
		done
	done
	../db-update

	../cron-jobs/sourceballs
	for pkgbase in "${pkgs[@]}"; do
		[ ! -r "${FTP_BASE}/${SRCPOOL}/${pkgbase}"-*"${SRCEXT}" ] && fail "source package not found!"
	done
}

testAnySourceballs() {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in "${pkgs[@]}"; do
		releasePackage extra "${pkgbase}" any
	done
	../db-update

	../cron-jobs/sourceballs
	for pkgbase in "${pkgs[@]}"; do
		[ ! -r "${FTP_BASE}/${SRCPOOL}/${pkgbase}"-*"${SRCEXT}" ] && fail "source package not found!"
	done
}

testSplitSourceballs() {
	local pkgs=('pkg-split-a' 'pkg-split-b')
	local pkg
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			releasePackage extra "${pkgbase}" "${arch}"
		done
	done

	../db-update

	../cron-jobs/sourceballs
	for pkgbase in "${pkgs[@]}"; do
		[ ! -r "${FTP_BASE}/${SRCPOOL}/${pkgbase}"-*"${SRCEXT}" ] && fail "source package not found!"
	done
}

testSourceballsCleanup() {
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			releasePackage extra "${pkgbase}" "${arch}"
		done
	done
	../db-update
	../cron-jobs/sourceballs

	for arch in "${ARCH_BUILD[@]}"; do
		../db-remove extra "${arch}" pkg-simple-a
	done

	../cron-jobs/sourceballs
	[ -r "${FTP_BASE}/${SRCPOOL}/pkg-simple-a"-*"${SRCEXT}" ] && fail "source package was not removed!"
	[ ! -r "${FTP_BASE}/${SRCPOOL}/pkg-simple-b"-*"${SRCEXT}" ] && fail "source package not found!"
}

. "${curdir}/../lib/shunit2"
