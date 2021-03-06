load ../lib/common

@test "create simple file lists" {
	local pkgs=('pkg-simple-a' 'pkg-simple-b' 'pkg-simple-epoch')
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
			if ! bsdtar -xOf "${FTP_BASE}/extra/os/${arch}/extra${FILESEXT}" | grep "usr/bin/${pkgbase}" &>/dev/null; then
				die "usr/bin/${pkgbase} not found in ${arch}/extra${FILESEXT}"
			fi
		done
	done
}

@test "create any file lists" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		releasePackage extra "${pkgbase}" any
	done
	db-update

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			if ! bsdtar -xOf "${FTP_BASE}/extra/os/${arch}/extra${FILESEXT}" | grep "usr/share/${pkgbase}/test" &>/dev/null; then
				die "usr/share/${pkgbase}/test not found in ${arch}/extra${FILESEXT}"
			fi
		done
	done
}

@test "create split file lists" {
	local pkgs=('pkg-split-a' 'pkg-split-b')
	local pkg
	local pkgbase
	local pkgname
	local pkgnames
	local arch

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			releasePackage extra "${pkgbase}" "${arch}"
		done
	done
	db-update

	for pkgbase in "${pkgs[@]}"; do
		pkgnames=($(source "${TMP}/svn-packages-copy/${pkgbase}/trunk/PKGBUILD"; echo "${pkgname[@]}"))
		for pkgname in "${pkgnames[@]}"; do
			for arch in "${ARCH_BUILD[@]}"; do
				if ! bsdtar -xOf "${FTP_BASE}/extra/os/${arch}/extra${FILESEXT}" | grep "usr/bin/${pkgname}" &>/dev/null; then
					die "usr/bin/${pkgname} not found in ${arch}/extra${FILESEXT}"
				fi
			done
		done
	done
}


@test "cleanup file lists" {
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

	for arch in "${ARCH_BUILD[@]}"; do
		if ! bsdtar -xOf "${FTP_BASE}/extra/os/${arch}/extra${FILESEXT}" | grep "usr/bin/pkg-simple-b" &>/dev/null; then
			die "usr/bin/pkg-simple-b not found in ${arch}/extra${FILESEXT}"
		fi
		if bsdtar -xOf "${FTP_BASE}/extra/os/${arch}/extra${FILESEXT}" | grep "usr/bin/pkg-simple-a" &>/dev/null; then
			die "usr/bin/pkg-simple-a still found in ${arch}/extra${FILESEXT}"
		fi
	done

}
