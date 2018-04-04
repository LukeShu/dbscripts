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
			for pkg in $(getPackageNamesFromPackageBase ${pkgbase}); do
				checkPackage extra "${pkg##*/}" "${arch}"
			done
		done
	done
}

@test "update any package" {
	releasePackage extra pkg-any-a any
	db-update

	updatePackage pkg-any-a any

	releasePackage extra pkg-any-a any
	db-update

	checkAnyPackage extra pkg-any-a-1-2-any.pkg.tar.xz any
}

@test "update any package to different repositories at once" {
	releasePackage extra pkg-any-a any

	updatePackage pkg-any-a any

	releasePackage testing pkg-any-a any

	db-update

	checkAnyPackage extra pkg-any-a-1-1-any.pkg.tar.xz any
	checkAnyPackage testing pkg-any-a-1-2-any.pkg.tar.xz any
}

@test "update same any package to same repository" {
	releasePackage extra pkg-any-a any
	db-update
	checkAnyPackage extra pkg-any-a-1-1-any.pkg.tar.xz any

	releasePackage extra pkg-any-a any
	run db-update
	[ "$status" -ne 0 ]
}

@test "update same any package to different repositories" {
	releasePackage extra pkg-any-a any
	db-update
	checkAnyPackage extra pkg-any-a-1-1-any.pkg.tar.xz any

	releasePackage testing pkg-any-a any
	run db-update
	[ "$status" -ne 0 ]

	local arch
	for arch in "${ARCH_BUILD[@]}"; do
		if [ -r "${FTP_BASE}/testing/os/${arch}/testing${DBEXT%.tar.*}" ]; then
			! bsdtar -xf "${FTP_BASE}/testing/os/${arch}/testing${DBEXT%.tar.*}" -O | grep "${pkgbase}" &>/dev/null
		fi
	done
}

@test "add incomplete split package" {
	skip # commented out with "This is fucking obnoxious" -- abslibre is broken
	local repo='extra'
	local pkgbase='pkg-split-a'
	local arch

	for arch in "${ARCH_BUILD[@]}"; do
		releasePackage "${repo}" "${pkgbase}" "${arch}"
	done

	# remove a split package to make db-update fail
	rm "${STAGING}/extra/${pkgbase}1-"*

	run db-update
	[ "$status" -ne 0 ]

	for arch in "${ARCH_BUILD[@]}"; do
		if [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" ]; then
			! bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${DBEXT%.tar.*}" -O | grep "${pkgbase}" &>/dev/null
		fi
	done
}

@test "unknown repo" {
	mkdir "${STAGING}/unknown/"
	releasePackage extra 'pkg-simple-a' 'i686'
	releasePackage unknown 'pkg-simple-b' 'i686'
	db-update
	checkPackage extra 'pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
	[ ! -e "${FTP_BASE}/unknown" ]
	rm -rf "${STAGING}/unknown/"
}

@test "add unsigned package fails" {
	releasePackage extra 'pkg-simple-a' 'i686'
	rm "${STAGING}"/extra/*.sig
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackage extra pkg-simple-a-1-1-i686.pkg.tar.xz i686
}

@test "add invalid signed package fails" {
	local p
	releasePackage extra 'pkg-simple-a' 'i686'
	for p in "${STAGING}"/extra/*${PKGEXT}; do
		unxz "$p"
		xz -0 "${p%%.xz}"
	done
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackage extra pkg-simple-a-1-1-i686.pkg.tar.xz i686
}

@test "add broken signature fails" {
	local s
	releasePackage extra 'pkg-simple-a' 'i686'
	for s in "${STAGING}"/extra/*.sig; do
		echo 0 > "$s"
	done
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackage extra pkg-simple-a-1-1-i686.pkg.tar.xz i686
}

@test "add package with inconsistent version fails" {
	local p
	releasePackage extra 'pkg-simple-a' 'i686'

	for p in "${STAGING}"/extra/*; do
		mv "${p}" "${p/pkg-simple-a-1/pkg-simple-a-2}"
	done

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackage extra 'pkg-simple-a-2-1-i686.pkg.tar.xz' 'i686'
}

@test "add package with inconsistent name fails" {
	local p
	releasePackage extra 'pkg-simple-a' 'i686'

	for p in "${STAGING}"/extra/*; do
		mv "${p}" "${p/pkg-/foo-pkg-}"
	done

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackage extra 'foo-pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
}

@test "add package with inconsistent pkgbuild fails" {
	skip # abslibre is broken
	releasePackage extra 'pkg-simple-a' 'i686'

	updateRepoPKGBUILD 'pkg-simple-a' extra i686

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackage extra 'pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
}

@test "add package with insufficient permissions fails" {
	releasePackage core 'pkg-simple-a' 'i686'
	releasePackage extra 'pkg-simple-b' 'i686'

	chmod -xwr ${FTP_BASE}/core/os/i686
	run db-update
	[ "$status" -ne 0 ]
	chmod +xwr ${FTP_BASE}/core/os/i686

	checkRemovedPackage core 'pkg-simple-a-1-1-i686.pkg.tar.xz' 'i686'
	checkRemovedPackage extra 'pkg-simple-b-1-1-i686.pkg.tar.xz' 'i686'
}

@test "package has to be a regular file" {
	local p
	local target=$(mktemp -d)

	for arch in "${ARCH_BUILD[@]}"; do
		releasePackage extra 'pkg-simple-a' $arch
	done

	for p in "${STAGING}"/extra/*i686*; do
		mv "${p}" "${target}"
		ln -s "${target}/${p##*/}" "${p}"
	done

	run db-update
	[ "$status" -ne 0 ]
	for arch in "${ARCH_BUILD[@]}"; do
		checkRemovedPackage extra "pkg-simple-a-1-1-${arch}.pkg.tar.xz" $arch
	done
}
