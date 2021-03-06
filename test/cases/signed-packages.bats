load ../lib/common

@test "add signed package" {
	releasePackage extra 'pkg-simple-a' 'i686'
	db-update
}

@test "add unsigned package" {
	releasePackage extra 'pkg-simple-a' 'i686'
	rm "${STAGING}"/extra/*.sig
	! db-update >/dev/null 2>&1
}

@test "add invalid signed package" {
	local p
	releasePackage extra 'pkg-simple-a' 'i686'
	for p in "${STAGING}"/extra/*${PKGEXT}; do
		unxz "$p"
		xz -0 "${p%%.xz}"
	done
	! db-update >/dev/null 2>&1
}

@test "add broken signature" {
	local s
	releasePackage extra 'pkg-simple-a' 'i686'
	for s in "${STAGING}"/extra/*.sig; do
		echo 0 > "$s"
	done
	! db-update >/dev/null 2>&1
}
