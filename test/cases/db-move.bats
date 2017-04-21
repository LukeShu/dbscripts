load ../lib/common

@test "move simple packages" {
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		releasePackage testing "${pkgbase}"
	done

	db-update

	db-move testing extra pkg-simple-a

	for arch in "${ARCH_BUILD[@]}"; do
		checkPackage extra "pkg-simple-a-1-1-${arch}.pkg.tar.xz" "${arch}"
		checkRemovedPackage testing pkg-simple-a "${arch}"

		checkPackage testing "pkg-simple-b-1-1-${arch}.pkg.tar.xz" "${arch}"
	done
}

@test "move multiple packages" {
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		releasePackage testing "${pkgbase}"
	done

	db-update

	db-move testing extra pkg-simple-a pkg-simple-b

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			checkPackage extra "${pkgbase}-1-1-${arch}.pkg.tar.xz" "${arch}"
			checkRemovedPackage testing "${pkgbase}" "${arch}"
		done
	done
}

@test "move epoch packages" {
	local pkgs=('pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		releasePackage testing "${pkgbase}"
	done

	db-update

	db-move testing extra pkg-simple-epoch

	for arch in "${ARCH_BUILD[@]}"; do
		checkPackage extra "pkg-simple-epoch-1:1-1-${arch}.pkg.tar.xz" "${arch}"
		checkRemovedPackage testing pkg-simple-epoch "${arch}"
	done
}

@test "move any packages" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in "${pkgs[@]}"; do
		releasePackage testing "${pkgbase}"
	done

	db-update
	db-move testing extra pkg-any-a

	checkPackage extra pkg-any-a-1-1-any.pkg.tar.xz any
	checkRemovedPackage testing pkg-any-a any
	checkPackage testing pkg-any-b-1-1-any.pkg.tar.xz any
}

@test "move split packages" {
	local pkgs=('pkg-split-a' 'pkg-split-b')
	local pkg
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		releasePackage testing "${pkgbase}"
	done

	db-update
	db-move testing extra pkg-split-a

	for arch in "${ARCH_BUILD[@]}"; do
		for pkg in $(getPackageNamesFromPackageBase pkg-split-a); do
			checkPackage extra "${pkg##*/}" "${arch}"
		done
		for pkg in $(getPackageNamesFromPackageBase pkg-split-b); do
			checkPackage testing "${pkg##*/}" "${arch}"
		done
	done
}
