load ../lib/common

@test "remove packages" {
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
			db-repo-remove extra "${arch}" "${pkgbase}"
		done
	done

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			checkRemovedPackageDB extra "${pkgbase}" "${arch}"
		done
	done
}

@test "remove multiple packages" {
	local pkgs=('pkg-simple-a' 'pkg-simple-b' 'pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			releasePackage extra "${pkgbase}" "${arch}"
		done
	done

	db-update

	for arch in "${ARCH_BUILD[@]}"; do
		db-repo-remove extra "${arch}" "${pkgs[@]}"
	done

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			checkRemovedPackageDB extra "${pkgbase}" "${arch}"
		done
	done
}
