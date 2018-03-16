load ../lib/common

@test "remove packages" {
	local pkgs=('pkg-simple-a' 'pkg-simple-b' 'pkg-split-a' 'pkg-split-b' 'pkg-simple-epoch')
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
			db-remove extra "${arch}" "${pkgbase}"
		done
	done

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			checkRemovedPackage extra "${pkgbase}" "${arch}"
		done
	done
}

@test "remove multiple packages" {
	local pkgs=('pkg-simple-a' 'pkg-simple-b' 'pkg-split-a' 'pkg-split-b' 'pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			releasePackage extra "${pkgbase}" "${arch}"
		done
	done

	db-update

	for arch in "${ARCH_BUILD[@]}"; do
		db-remove extra "${arch}" "${pkgs[@]}"
	done

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			checkRemovedPackage extra "${pkgbase}" "${arch}"
		done
	done
}

@test "remove any packages" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in "${pkgs[@]}"; do
		releasePackage extra "${pkgbase}" any
	done

	db-update

	for pkgbase in "${pkgs[@]}"; do
		db-remove extra any "${pkgbase}"
	done

	for pkgbase in "${pkgs[@]}"; do
		checkRemovedAnyPackage extra "${pkgbase}"
	done
}
