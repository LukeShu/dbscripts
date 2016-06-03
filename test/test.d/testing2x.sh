#!/bin/bash

curdir="$(dirname "$(readlink -e "$0")")"
. "${curdir}/../lib/common.inc"

testTesting2xAnyPackage() {
	releasePackage core pkg-any-a any
	../db-update

	pushd "${TMP}/svn-packages-copy/pkg-any-a/trunk/" >/dev/null
	sed 's/pkgrel=1/pkgrel=2/g' -i PKGBUILD
	arch_svn commit -q -m"update pkg to pkgrel=2" >/dev/null
	sudo libremakepkg
	mv pkg-any-a-1-2-any.pkg.tar.xz "${pkgdir}/pkg-any-a/"
	popd >/dev/null

	releasePackage testing pkg-any-a any
	../db-update
	rm -f "${pkgdir}/pkg-any-a/pkg-any-a-1-2-any.pkg.tar.xz"

	../testing2x pkg-any-a

	checkAnyPackage core pkg-any-a-1-2-any.pkg.tar.xz any
	checkRemovedAnyPackage testing pkg-any-a
}

. "${curdir}/../lib/shunit2"
