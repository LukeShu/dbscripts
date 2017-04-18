load ../lib/common

@test "add simple packages" {
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			releasePackage extra "$pkgbase" "$arch"
			mv "${STAGING}"/extra/* "${FTP_BASE}/${PKGPOOL}/"
			ln -s "${FTP_BASE}/${PKGPOOL}/${pkgbase}-1-1-${arch}.pkg.tar.xz" "${FTP_BASE}/extra/os/${arch}/"
			ln -s "${FTP_BASE}/${PKGPOOL}/${pkgbase}-1-1-${arch}.pkg.tar.xz.sig" "${FTP_BASE}/extra/os/${arch}/"
			db-repo-add extra "${arch}" "${pkgbase}-1-1-${arch}.pkg.tar.xz"
		done
	done

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			checkPackageDB extra "${pkgbase}-1-1-${arch}.pkg.tar.xz" "${arch}"
		done
	done
}

@test "add multiple packages" {
	local pkgs=('pkg-simple-a' 'pkg-simple-b')
	local pkgbase
	local arch

	for arch in "${ARCH_BUILD[@]}"; do
		add_pkgs=()
		for pkgbase in "${pkgs[@]}"; do
			releasePackage extra "$pkgbase" "$arch"
			mv "${STAGING}"/extra/* "${FTP_BASE}/${PKGPOOL}/"
			ln -s "${FTP_BASE}/${PKGPOOL}/${pkgbase}-1-1-${arch}.pkg.tar.xz" "${FTP_BASE}/extra/os/${arch}/"
			ln -s "${FTP_BASE}/${PKGPOOL}/${pkgbase}-1-1-${arch}.pkg.tar.xz.sig" "${FTP_BASE}/extra/os/${arch}/"
			add_pkgs+=("${pkgbase}-1-1-${arch}.pkg.tar.xz")
		done
		db-repo-add extra "${arch}" "${add_pkgs[@]}"
	done

	for pkgbase in "${pkgs[@]}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			checkPackageDB extra "${pkgbase}-1-1-${arch}.pkg.tar.xz" "${arch}"
		done
	done
}

@test "add any packages" {
	local pkgs=('pkg-any-a' 'pkg-any-b')
	local pkgbase
	local arch

	for pkgbase in ${pkgs[@]}; do
		releasePackage extra ${pkgbase} any
		mv "${STAGING}"/extra/* "${FTP_BASE}/${PKGPOOL}/"
		for arch in "${ARCH_BUILD[@]}"; do
			ln -s "${FTP_BASE}/${PKGPOOL}/${pkgbase}-1-1-any.pkg.tar.xz" "${FTP_BASE}/extra/os/${arch}/"
			ln -s "${FTP_BASE}/${PKGPOOL}/${pkgbase}-1-1-any.pkg.tar.xz.sig" "${FTP_BASE}/extra/os/${arch}/"
		done
		db-repo-add extra any ${pkgbase}-1-1-any.pkg.tar.xz
	done

	for pkgbase in ${pkgs[@]}; do
		for arch in "${ARCH_BUILD[@]}"; do
			checkPackageDB extra ${pkgbase}-1-1-any.pkg.tar.xz ${arch}
		done
	done
}
