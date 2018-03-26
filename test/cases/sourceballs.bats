load ../lib/common

@test "sourceballs" {
	local pkgs=('pkg-simple-a' 'pkg-simple-b' 'pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			releasePackage extra "${pkgbase}" "${arch}"
		done
	done
	db-update

	sourceballs
	for pkgbase in "${pkgs[@]}"; do
		[ -r "${FTP_BASE}/${SRCPOOL}/${pkgbase}"-*"${SRCEXT}" ]
	done
}

@test "any sourceballs" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in "${pkgs[@]}"; do
		releasePackage extra "${pkgbase}" any
	done
	db-update

	sourceballs
	for pkgbase in "${pkgs[@]}"; do
		[ -r "${FTP_BASE}/${SRCPOOL}/${pkgbase}"-*"${SRCEXT}" ]
	done
}

@test "split sourceballs" {
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

	sourceballs
	for pkgbase in "${pkgs[@]}"; do
		[ -r "${FTP_BASE}/${SRCPOOL}/${pkgbase}"-*"${SRCEXT}" ]
	done
}

@test "sourceballs cleanup" {
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			releasePackage extra "${pkgbase}" "${arch}"
		done
	done
	db-update
	sourceballs

	for arch in "${ARCH_BUILD[@]}"; do
		db-remove extra "${arch}" pkg-simple-a
	done

	sourceballs
	[ ! -r "${FTP_BASE}/${SRCPOOL}/pkg-simple-a"-*"${SRCEXT}" ]
	[ -r "${FTP_BASE}/${SRCPOOL}/pkg-simple-b"-*"${SRCEXT}" ]
}
