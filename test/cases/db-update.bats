load ../lib/common

@test "add simple packages" {
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		releasePackage extra "${pkgbase}"
	done

	db-update

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			checkPackage extra "${pkgbase}-1-1-${arch}.pkg.tar.xz" "${arch}"
		done
	done
}

@test "add single simple package" {
	releasePackage extra 'pkg-single-arch'
	db-update
	checkPackage extra 'pkg-single-arch-1-1-x86_64.pkg.tar.xz' 'x86_64'
}

@test "add single epoch package" {
	releasePackage extra 'pkg-single-epoch'
	db-update
	checkPackage extra 'pkg-single-epoch-1:1-1-x86_64.pkg.tar.xz' 'x86_64'
}

@test "add any packages" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in "${pkgs[@]}"; do
		releasePackage extra "${pkgbase}"
	done

	db-update

	for pkgbase in "${pkgs[@]}"; do
		checkPackage extra "${pkgbase}-1-1-any.pkg.tar.xz" any
	done
}

@test "add split packages" {
	local pkgs=('pkg-split-a' 'pkg-split-b')
	local pkg
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		releasePackage extra "${pkgbase}"
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
	releasePackage extra pkg-any-a
	db-update

	updatePackage pkg-any-a

	releasePackage extra pkg-any-a
	db-update

	checkPackage extra pkg-any-a-1-2-any.pkg.tar.xz any
}

@test "update any package to different repositories at once" {
	releasePackage extra pkg-any-a

	updatePackage pkg-any-a

	releasePackage testing pkg-any-a

	db-update

	checkPackage extra pkg-any-a-1-1-any.pkg.tar.xz any
	checkPackage testing pkg-any-a-1-2-any.pkg.tar.xz any
}

@test "update same any package to same repository" {
	releasePackage extra pkg-any-a
	db-update
	checkPackage extra pkg-any-a-1-1-any.pkg.tar.xz any

	releasePackage extra pkg-any-a
	run db-update
	[ "$status" -ne 0 ]
}

@test "update same any package to different repositories" {
	releasePackage extra pkg-any-a
	db-update
	checkPackage extra pkg-any-a-1-1-any.pkg.tar.xz any

	releasePackage testing pkg-any-a
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackageDB testing pkg-any-a any
}

@test "add incomplete split package" {
	skip # commented out with "This is fucking obnoxious" -- abslibre is broken
	local repo='extra'
	local pkgbase='pkg-split-a'
	local arch

	releasePackage "${repo}" "${pkgbase}"

	# remove a split package to make db-update fail
	rm "${STAGING}/extra/${pkgbase}1-"*

	run db-update
	[ "$status" -ne 0 ]

	for arch in "${ARCH_BUILD[@]}"; do
		checkRemovedPackageDB ${repo} ${pkgbase} ${arch}
	done
}

@test "unknown repo" {
	mkdir "${STAGING}/unknown/"
	releasePackage extra 'pkg-any-a'
	releasePackage unknown 'pkg-any-b'
	db-update
	checkPackage extra 'pkg-any-a-1-1-any.pkg.tar.xz' any
	[ ! -e "${FTP_BASE}/unknown" ]
	rm -rf "${STAGING}/unknown/"
}

@test "add unsigned package fails" {
	releasePackage extra 'pkg-any-a'
	rm "${STAGING}"/extra/*.sig
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackageDB extra pkg-any-a any
}

@test "add invalid signed package fails" {
	local p
	releasePackage extra 'pkg-any-a'
	for p in "${STAGING}"/extra/*${PKGEXT}; do
		unxz "$p"
		xz -0 "${p%%.xz}"
	done
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackageDB extra pkg-any-a any
}

@test "add broken signature fails" {
	local s
	releasePackage extra 'pkg-any-a'
	for s in "${STAGING}"/extra/*.sig; do
		echo 0 > "$s"
	done
	run db-update
	[ "$status" -ne 0 ]

	checkRemovedPackageDB extra pkg-any-a any
}

@test "add package with inconsistent version fails" {
	local p
	releasePackage extra 'pkg-any-a'

	for p in "${STAGING}"/extra/*; do
		mv "${p}" "${p/pkg-any-a-1/pkg-any-a-2}"
	done

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackageDB extra 'pkg-any-a' 'any'
}

@test "add package with inconsistent name fails" {
	local p
	releasePackage extra 'pkg-any-a'

	for p in "${STAGING}"/extra/*; do
		mv "${p}" "${p/pkg-/foo-pkg-}"
	done

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackage extra 'foo-pkg-any-a' 'any'
}

@test "add package with inconsistent pkgbuild fails" {
	skip # abslibre is broken
	releasePackage extra 'pkg-any-a'

	updateRepoPKGBUILD 'pkg-any-a' extra any

	run db-update
	[ "$status" -ne 0 ]
	checkRemovedPackageDB extra 'pkg-any-a' 'any'
}

@test "add package with insufficient permissions fails" {
	releasePackage core 'pkg-any-a'
	releasePackage extra 'pkg-any-b'

	chmod -xwr ${FTP_BASE}/core/os/i686
	run db-update
	[ "$status" -ne 0 ]
	chmod +xwr ${FTP_BASE}/core/os/i686

	checkRemovedPackageDB core 'pkg-any-a' 'any'
	checkRemovedPackageDB extra 'pkg-any-b' 'any'
}

@test "package has to be a regular file" {
	local p
	local target=$(mktemp -d)

	releasePackage extra 'pkg-simple-a'

	for p in "${STAGING}"/extra/*i686*; do
		mv "${p}" "${target}"
		ln -s "${target}/${p##*/}" "${p}"
	done

	run db-update
	[ "$status" -ne 0 ]
	for arch in "${ARCH_BUILD[@]}"; do
		checkRemovedPackageDB extra "pkg-simple-a" $arch
	done
}
