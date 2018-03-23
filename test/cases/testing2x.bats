load ../lib/common

@test "testing2x any package" {
	releasePackage core pkg-any-a any
	db-update

	pushd "${TMP}/svn-packages-copy/pkg-any-a/trunk/" >/dev/null
	sed 's/pkgrel=1/pkgrel=2/g' -i PKGBUILD
	svn commit -q -m"update pkg to pkgrel=2" >/dev/null
	sudo libremakepkg
	mv pkg-any-a-1-2-any.pkg.tar.xz "${pkgdir}/pkg-any-a/"
	popd >/dev/null

	releasePackage testing pkg-any-a any
	db-update
	rm -f "${pkgdir}/pkg-any-a/pkg-any-a-1-2-any.pkg.tar.xz"

	testing2x pkg-any-a

	checkAnyPackage core pkg-any-a-1-2-any.pkg.tar.xz any
	checkRemovedAnyPackage testing pkg-any-a
}
