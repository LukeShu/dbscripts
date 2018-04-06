load ../lib/common

__checkRepoRemovedPackage() {
	local repo=$1
	local pkgbase=$2
	local arch=$3

	# FIXME: pkgbase might not be part of the package filename
	[[ ! -f ${FTP_BASE}/${PKGPOOL}/${pkgbase}*${PKGEXT} ]]
	[[ ! -f ${FTP_BASE}/${repo}/os/${arch}/${pkgbase}*${PKGEXT} ]]
}

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

	ftpdir-cleanup

	for arch in "${ARCH_BUILD[@]}"; do
		checkRemovedPackage extra 'pkg-simple-a' "${arch}"
		__checkRepoRemovedPackage extra 'pkg-simple-a' ${arch}

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

	ftpdir-cleanup

	for arch in "${ARCH_BUILD[@]}"; do
		checkRemovedPackage extra 'pkg-simple-epoch' "${arch}"
		__checkRepoRemovedPackage extra 'pkg-simple-epoch' ${arch}
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
	ftpdir-cleanup

	local pkg1='pkg-any-a-1-1-any.pkg.tar.xz'
	checkRemovedPackage extra 'pkg-any-a' any
	__checkRepoRemovedPackage extra 'pkg-any-a' any

	local pkg2="pkg-any-b-1-1-${arch}.pkg.tar.xz"
	checkPackage extra "${pkg2}" any
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

	ftpdir-cleanup

	for arch in "${ARCH_BUILD[@]}"; do
		for pkg in $(getPackageNamesFromPackageBase "${pkgs[0]}"); do
			checkRemovedPackage extra "${pkg}" "${arch}"
			__checkRepoRemovedPackage extra ${pkg} ${arch}
		done

		for pkg in $(getPackageNamesFromPackageBase "${pkgs[1]}"); do
			checkPackage extra "${pkg##*/}" "${arch}"
		done
	done
}

@test "cleanup old packages" {
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		for arch in "${ARCH_BUILD[@]}"; do
			releasePackage extra ${pkgbase} ${arch}
		done
	done

	db-update

	for pkgbase in ${pkgs[@]}; do
		for arch in "${ARCH_BUILD[@]}"; do
			db-remove extra ${arch} ${pkgbase}
		done
	done

	ftpdir-cleanup

	local pkgfilea="pkg-simple-a-1-1-${arch}.pkg.tar.xz"
	local pkgfileb="pkg-simple-b-1-1-${arch}.pkg.tar.xz"
	for arch in "${ARCH_BUILD[@]}"; do
		touch -d "-$(expr ${CLEANUP_KEEP} + 1)days" ${CLEANUP_DESTDIR}/${pkgfilea}{,.sig}
	done

	ftpdir-cleanup

	[ ! -f ${CLEANUP_DESTDIR}/${pkgfilea} ]
	[ -f ${CLEANUP_DESTDIR}/${pkgfileb} ]
}
