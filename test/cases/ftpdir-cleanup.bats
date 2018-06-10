load ../lib/common

__getPackageNamesFromPackageBase() {
	local pkgbase=$1

	(. "fixtures/${pkgbase}/PKGBUILD"; echo ${pkgname[@]})
}

__checkRepoRemovedPackage() {
	local repo=$1
	local pkgbase=$2
	local repoarch=$3
	local pkgname

	for pkgname in $(__getPackageNamesFromPackageBase ${pkgbase}); do
		! __isGlobfile "${FTP_BASE}/${PKGPOOL}/${pkgname}"-*"${PKGEXT}"
		! __isGlobfile "${FTP_BASE}/${repo}/os/${repoarch}/${pkgname}"-*"${PKGEXT}"
	done
}

@test "cleanup simple packages" {
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		releasePackage extra "${pkgbase}"
	done

	db-update

	for arch in "${ARCH_BUILD[@]}"; do
		db-remove extra "${arch}" pkg-simple-a
	done

	ftpdir-cleanup

	checkRemovedPackage extra 'pkg-simple-a'
	for arch in "${ARCH_BUILD[@]}"; do
		__checkRepoRemovedPackage extra 'pkg-simple-a' ${arch}
	done

	checkPackage extra pkg-simple-b
}

@test "cleanup epoch packages" {
	local pkgs=('pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		releasePackage extra "${pkgbase}"
	done

	db-update

	for arch in "${ARCH_BUILD[@]}"; do
		db-remove extra "${arch}" pkg-simple-epoch
	done

	ftpdir-cleanup

	checkRemovedPackage extra 'pkg-simple-epoch'
	for arch in "${ARCH_BUILD[@]}"; do
		__checkRepoRemovedPackage extra 'pkg-simple-epoch' ${arch}
	done
}

@test "cleanup any packages" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase
	local arch='any'

	for pkgbase in "${pkgs[@]}"; do
		releasePackage extra "${pkgbase}"
	done

	db-update
	db-remove extra any pkg-any-a
	ftpdir-cleanup

	local pkg1="pkg-any-a-1-1-any${PKGEXT}"
	checkRemovedPackage extra 'pkg-any-a'
	for arch in ${ARCH_BUILD[@]}; do
		__checkRepoRemovedPackage extra 'pkg-any-a' ${arch}
	done

	checkPackage extra pkg-any-b
}

@test "cleanup split packages" {
	local pkgs=('pkg-split-a' 'pkg-split-b')
	local pkg
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		releasePackage extra "${pkgbase}"
	done

	db-update

	for arch in "${ARCH_BUILD[@]}"; do
		db-remove extra "${arch}" "${pkgs[0]}"
	done

	ftpdir-cleanup

	for arch in "${ARCH_BUILD[@]}"; do
		__checkRepoRemovedPackage extra ${pkgs[0]} ${arch}
	done

	checkRemovedPackage extra "${pkgs[0]}"
	checkPackage extra "${pkgs[1]}"
}

@test "cleanup old packages" {
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase}
	done

	db-update

	for pkgbase in ${pkgs[@]}; do
		for arch in "${ARCH_BUILD[@]}"; do
			db-remove extra ${arch} ${pkgbase}
		done
	done

	ftpdir-cleanup

	local pkgfilea="pkg-simple-a-1-1-${arch}${PKGEXT}"
	local pkgfileb="pkg-simple-b-1-1-${arch}${PKGEXT}"
	for arch in "${ARCH_BUILD[@]}"; do
		touch -d "-$(expr ${CLEANUP_KEEP} + 1)days" ${CLEANUP_DESTDIR}/${pkgfilea}{,.sig}
	done

	ftpdir-cleanup

	[ ! -f ${CLEANUP_DESTDIR}/${pkgfilea} ]
	[ -f ${CLEANUP_DESTDIR}/${pkgfileb} ]
}
