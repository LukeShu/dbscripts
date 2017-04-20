load ../lib/common

@test "packages" {
	local result
	local pkg
	local pkgbase
	local pkgarchs
	local pkgarch
	local tmp
	tmp=$(mktemp -d)

	# FIXME: Evaluate if this test is sane and even needed

	cp -rL fixtures/* "${tmp}"

	for pkgbase in "${tmp}"/*; do
		pushd "${pkgbase}"
		run namcap -e pkgnameindesc,tags PKGBUILD
		[ -z "$output" ]

		__buildPackage

		# FIXME: Is overriding IFS a bats bug?
		IFS=' '
		pkgarchs=($(. PKGBUILD; echo ${arch[@]}))
		for pkgarch in "${pkgarchs[@]}"; do
			echo "Building ${pkgbase} on ${pkgarch}"
			if [[ $pkgarch != "$ARCH_HOST" && $pkgarch != any ]]; then
				# Cross-arch namcap is silly:
				#
				#   W: Referenced library 'libc.so.6' is an uninstalled dependency
				#   W: Dependency included and not needed ('glibc')»
				continue
			fi
			for pkg in *-${pkgarch}${PKGEXT}; do
				msg 'run namcap -e pkgnameindesc %q' "${pkg}"
				run namcap -e pkgnameindesc "${pkg}"
				printf '%s\n' "$output" | sed 's/^/> /'
				cp "$pkg" -t /tmp -f
				[ -z "$output" ]
			done
		done
		popd
	done
}
