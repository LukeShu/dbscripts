load ../lib/common

@test "cleanup simple packages" {
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			releasePackage extra "${pkgbase}" "${arch}"
		done
	done

	db-update

	for arch in "${ARCH_BUILD[@]}"; do
		db-remove extra "${arch}" pkg-simple-a
	done

	ftpdir-cleanup >/dev/null

	for arch in "${ARCH_BUILD[@]}"; do
		local pkg1="pkg-simple-a-1-1-${arch}.pkg.tar.xz"
		checkRemovedPackage extra 'pkg-simple-a' "${arch}"
		[ ! -f "${FTP_BASE}/${PKGPOOL}/${pkg1}" ]
		[ ! -f "${FTP_BASE}/${repo}/os/${arch}/${pkg1}" ]

		local pkg2="pkg-simple-b-1-1-${arch}.pkg.tar.xz"
		checkPackage extra "${pkg2}" "${arch}"
	done
}

@test "cleanup epoch packages" {
	local pkgs=('pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			releasePackage extra "${pkgbase}" "${arch}"
		done
	done

	db-update

	for arch in "${ARCH_BUILD[@]}"; do
		db-remove extra "${arch}" pkg-simple-epoch
	done

	ftpdir-cleanup >/dev/null

	for arch in "${ARCH_BUILD[@]}"; do
		local pkg1="pkg-simple-epoch-1:1-1-${arch}.pkg.tar.xz"
		checkRemovedPackage extra 'pkg-simple-epoch' "${arch}"
		[ ! -f "${FTP_BASE}/${PKGPOOL}/${pkg1}" ]
		[ ! -f "${FTP_BASE}/${repo}/os/${arch}/${pkg1}" ]
	done
}

@test "cleanup any packages" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase
	local arch='any'

	for pkgbase in "${pkgs[@]}"; do
		releasePackage extra "${pkgbase}" any
	done

	db-update
	db-remove extra any pkg-any-a
	ftpdir-cleanup >/dev/null

	local pkg1='pkg-any-a-1-1-any.pkg.tar.xz'
	checkRemovedAnyPackage extra 'pkg-any-a'
	[ ! -f "${FTP_BASE}/${PKGPOOL}/${pkg1}" ]
	[ ! -f "${FTP_BASE}/${repo}/os/${arch}/${pkg1}" ]

	local pkg2="pkg-any-b-1-1-${arch}.pkg.tar.xz"
	checkAnyPackage extra "${pkg2}"
}

@test "cleanup split packages" {
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

	for arch in "${ARCH_BUILD[@]}"; do
		db-remove extra "${arch}" "${pkgs[0]}"
	done

	ftpdir-cleanup >/dev/null

	for arch in "${ARCH_BUILD[@]}"; do
		for pkg in $(getPackageNamesFromPackageBase "${pkgs[0]}"); do
			checkRemovedPackage extra "${pkgs[0]}" "${arch}"
			[ ! -f "${FTP_BASE}/${PKGPOOL}/${pkg}" ]
			[ ! -f "${FTP_BASE}/${repo}/os/${arch}/${pkg}" ]
		done

		for pkg in $(getPackageNamesFromPackageBase "${pkgs[1]}"); do
			checkPackage extra "${pkg##*/}" "${arch}"
		done
	done
}
