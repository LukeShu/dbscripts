load ../lib/common

@test "add simple packages" {
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			releasePackage extra "${pkgbase}" "${arch}"
		done
	done

	db-update

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			checkPackage extra "${pkgbase}-1-1-${arch}.pkg.tar.xz" "${arch}"
		done
	done
}

@test "add single simple package" {
	releasePackage extra 'pkg-simple-a' 'i686'
	db-update
	checkPackage extra 'pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
}

@test "add single epoch package" {
	releasePackage extra 'pkg-simple-epoch' 'i686'
	db-update
	checkPackage extra 'pkg-simple-epoch-1:1-1-i686.pkg.tar.xz' 'i686'
}

@test "add any packages" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in "${pkgs[@]}"; do
		releasePackage extra "${pkgbase}" any
	done

	db-update

	for pkgbase in "${pkgs[@]}"; do
		checkAnyPackage extra "${pkgbase}-1-1-any.pkg.tar.xz"
	done
}

@test "add split packages" {
	local pkgs=('pkg-split-a' 'pkg-split-b')
	local pkg
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			releasePackage extra "${pkgbase}" "${arch}"
		done
	done

	db-update

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			for pkg in "${pkgdir}/${pkgbase}"/*-"${arch}"${PKGEXT}; do
				checkPackage extra "${pkg##*/}" "${arch}"
			done
		done
	done
}

@test "update any package" {
	releasePackage extra pkg-any-a any
	db-update

	pushd "${TMP}/svn-packages-copy/pkg-any-a/trunk/" >/dev/null
	sed 's/pkgrel=1/pkgrel=2/g' -i PKGBUILD
	svn commit -q -m"update pkg to pkgrel=2" >/dev/null
	sudo libremakepkg
	mv pkg-any-a-1-2-any.pkg.tar.xz "${pkgdir}/pkg-any-a/"
	popd >/dev/null

	releasePackage extra pkg-any-a any
	db-update

	checkAnyPackage extra pkg-any-a-1-2-any.pkg.tar.xz any

	rm -f "${pkgdir}/pkg-any-a/pkg-any-a-1-2-any.pkg.tar.xz"
}

@test "update any package to different repositories at once" {
	releasePackage extra pkg-any-a any

	pushd "${TMP}/svn-packages-copy/pkg-any-a/trunk/" >/dev/null
	sed 's/pkgrel=1/pkgrel=2/g' -i PKGBUILD
	svn commit -q -m"update pkg to pkgrel=2" >/dev/null
	sudo libremakepkg
	mv pkg-any-a-1-2-any.pkg.tar.xz "${pkgdir}/pkg-any-a/"
	popd >/dev/null

	releasePackage testing pkg-any-a any

	db-update

	checkAnyPackage extra pkg-any-a-1-1-any.pkg.tar.xz any
	checkAnyPackage testing pkg-any-a-1-2-any.pkg.tar.xz any

	rm -f "${pkgdir}/pkg-any-a/pkg-any-a-1-2-any.pkg.tar.xz"
}

@test "update same any package to same repository" {
	releasePackage extra pkg-any-a any
	db-update
	checkAnyPackage extra pkg-any-a-1-1-any.pkg.tar.xz any

	releasePackage extra pkg-any-a any
	db-update >/dev/null 2>&1 && (fail 'Adding an existing package to the same repository should fail'; return 1)
}

@test "update same any package to different repositories" {
	releasePackage extra pkg-any-a any
	db-update
	checkAnyPackage extra pkg-any-a-1-1-any.pkg.tar.xz any

	releasePackage testing pkg-any-a any
	db-update >/dev/null 2>&1 && (fail 'Adding an existing package to another repository should fail'; return 1)

	local arch
	for arch in "${ARCH_BUILD[@]}"; do
		( [ -r "${FTP_BASE}/testing/os/${arch}/testing${DBEXT%.tar.*}" ] \
			&& bsdtar -xf "${FTP_BASE}/testing/os/${arch}/testing${DBEXT%.tar.*}" -O | grep "${pkgbase}" &>/dev/null) \
			&& fail "${pkgbase} should not be in testing/os/${arch}/testing${DBEXT%.tar.*}"
	done
}


@test "add incomplete split package" {
	local repo='extra'
	local pkgbase='pkg-split-a'
	local arch

	for arch in "${ARCH_BUILD[@]}"; do
		releasePackage "${repo}" "${pkgbase}" "${arch}"
	done

	# remove a split package to make db-update fail
	rm "${STAGING}/extra/${pkgbase}1-"*

	db-update >/dev/null 2>&1 && fail "db-update should fail when a split package is missing!"

	for arch in "${ARCH_BUILD[@]}"; do
		( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" ] \
		&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" -O | grep "${pkgbase}" &>/dev/null) \
		&& fail "${pkgbase} should not be in ${repo}/os/${arch}/${repo}${DBEXT%.tar.*}"
	done
}

@test "unknown repo" {
	mkdir "${STAGING}/unknown/"
	releasePackage extra 'pkg-simple-a' 'i686'
	releasePackage unknown 'pkg-simple-b' 'i686'
	db-update
	checkPackage extra 'pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
	[ -e "${FTP_BASE}/unknown" ] && fail "db-update pushed a package into an unknown repository"
	rm -rf "${STAGING}/unknown/"
}
