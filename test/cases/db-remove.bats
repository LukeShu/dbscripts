load ../lib/common

@test "remove packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b' 'pkg-split-a' 'pkg-split-b' 'pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		releasePackage extra "${pkgbase}"
	done

	db-update

	for pkgbase in "${pkgs[@]}"; do
		for arch in ${arches[@]}; do
			db-remove extra "${arch}" "${pkgbase}"
		done
	done

	for pkgbase in "${pkgs[@]}"; do
		checkRemovedPackage extra "${pkgbase}"
	done
}

@test "remove multiple packages" {
	local arches=('i686' 'x86_64')
	local pkgs=('pkg-simple-a' 'pkg-simple-b' 'pkg-split-a' 'pkg-split-b' 'pkg-simple-epoch')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		releasePackage extra "${pkgbase}"
	done

	db-update

	for arch in ${arches[@]}; do
		db-remove extra "${arch}" "${pkgs[@]}"
	done

	for pkgbase in "${pkgs[@]}"; do
		checkRemovedPackage extra "${pkgbase}"
	done
}

@test "remove any packages" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase

	for pkgbase in "${pkgs[@]}"; do
		releasePackage extra "${pkgbase}"
	done

	db-update

	for pkgbase in "${pkgs[@]}"; do
		db-remove extra any "${pkgbase}"
	done

	for pkgbase in "${pkgs[@]}"; do
		checkRemovedPackage extra "${pkgbase}"
	done
}
