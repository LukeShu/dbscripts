#!/hint/bash
set -E

. "$(dirname "${BASH_SOURCE[0]}")/../../config"
. "$(dirname "${BASH_SOURCE[0]}")/../../config.testing"
. "$(dirname "${BASH_SOURCE[0]}")/../../db-functions"

signpkg() {
	if [[ -r '/etc/makepkg.conf' ]]; then
		source '/etc/makepkg.conf'
	else
		die '/etc/makepkg.conf not found!'
	fi
	if [[ -r ~/.makepkg.conf ]]; then
		. ~/.makepkg.conf
	fi
	if [[ -n $GPGKEY ]]; then
		SIGNWITHKEY=(-u "${GPGKEY}")
	fi
	gpg --detach-sign --use-agent "${SIGNWITHKEY[@]}" "${@}" || die
}

oneTimeSetUp() {
	local p
	local d
	local a
	local pkgname
	local pkgarch
	local pkgversion
	local build
	pkgdir="$(mktemp -dt "${0##*/}.XXXXXXXXXX")"
	cp -Lr "$(dirname "${BASH_SOURCE[0]}")"/../packages/* "${pkgdir}"
	msg 'Building packages...'
	for d in "${pkgdir}"/*; do
		pushd "$d" >/dev/null
		pkgname=($(. PKGBUILD; echo "${pkgname[@]}"))
		pkgarch=($(. PKGBUILD; echo "${arch[@]}"))
		pkgversion=$(. PKGBUILD; get_full_version)

		build=true
		for a in "${pkgarch[@]}"; do
			for p in "${pkgname[@]}"; do
				[ ! -f "${p}-${pkgversion}-${a}"${PKGEXT} ] && build=false
			done
		done

		if ! "${build}"; then
			if [ "${pkgarch[0]}" == 'any' ]; then
				sudo libremakepkg || die 'libremakepkg failed'
			else
				for a in "${pkgarch[@]}"; do
					if in_array "$a" "${ARCH_BUILD[@]}"; then
						sudo setarch "$a" libremakepkg -n "$a" || die "setarch ${a} libremakepkg -n ${a} failed"
						for p in "${pkgname[@]}"; do
							cp "${p}-${pkgversion}-${a}"${PKGEXT} "$(dirname "${BASH_SOURCE[0]})/../packages/${d##*/}")"
						done
					else
						warning "skipping arch %s" "$a"
					fi
				done
			fi
		fi
		popd >/dev/null
	done
}

oneTimeTearDown() {
	rm -rf "${pkgdir}"
}

setUp() {
	local p
	local pkg
	local r
	local a

	[ -f "$(dirname "${BASH_SOURCE[0]}")/../../config.local" ] && die "$(dirname "${BASH_SOURCE[0]}")/../../config.local exists"
	TMP="$(mktemp -dt "${0##*/}.XXXXXXXXXX")"
	#msg "Using ${TMP}"

	PKGREPOS=('core' 'extra' 'testing')
	PKGPOOL='pool/packages'
	SRCPOOL='pool/sources'
	mkdir -p "${TMP}/"{ftp,tmp,staging,{package,source}-cleanup,svn-packages-{copy,repo}}

	for r in "${PKGREPOS[@]}"; do
		mkdir -p "${TMP}/staging/${r}"
		for a in "${ARCHES[@]}"; do
			mkdir -p "${TMP}/ftp/${r}/os/${a}"
		done
	done
	mkdir -p "${TMP}/ftp/${PKGPOOL}"
	mkdir -p "${TMP}/ftp/${SRCPOOL}"

	msg 'Creating svn repository...'
	svnadmin create "${TMP}/svn-packages-repo"
	svn checkout -q "file://${TMP}/svn-packages-repo" "${TMP}/svn-packages-copy"

	for p in "${pkgdir}"/*; do
		pkg=${p##*/}
		mkdir -p "${TMP}/svn-packages-copy/${pkg}"/{trunk,repos}
		cp "${p}"/* "${TMP}/svn-packages-copy/${pkg}/trunk/"
		svn add -q "${TMP}/svn-packages-copy/${pkg}"
		svn commit -q -m"initial commit of ${pkg}" "${TMP}/svn-packages-copy"
	done

	mkdir -p "${TMP}/home/.config/libretools"
	export XDG_CONFIG_HOME="${TMP}/home/.config"
	printf '%s\n' \
		'SVNURL=foo' \
		"SVNREPO=\"${TMP}/svn-packages-copy\"" \
		"ARCHES=($(printf '%q ' "${BUILD_ARCHES[@]}"))" \
		> "$XDG_CONFIG_HOME/libretools/xbs-abs.conf"
	printf '%s\n' 'BUILDSYSTEM=abs' > "$XDG_CONFIG_HOME/xbs.conf"

	cat <<eot > "$(dirname "${BASH_SOURCE[0]}")/../../config.local"
	FTP_BASE="${TMP}/ftp"
	SVNREPO="file://${TMP}/svn-packages-repo"
	PKGREPOS=("${PKGREPOS[@]}")
	PKGPOOL="${PKGPOOL}"
	SRCPOOL="${SRCPOOL}"
	TESTING_REPO='testing'
	STABLE_REPOS=('core' 'extra')
	CLEANUP_DESTDIR="${TMP}/package-cleanup"
	SOURCE_CLEANUP_DESTDIR="${TMP}/source-cleanup"
	STAGING="${TMP}/staging"
	TMPDIR="${TMP}/tmp"
	CLEANUP_DRYRUN=false
	SOURCE_CLEANUP_DRYRUN=false
	REQUIRE_SIGNATURE=true
eot
	. "$(dirname "${BASH_SOURCE[0]}")/../../config"
}

tearDown() {
	rm -rf "${TMP}"
	rm -f "$(dirname "${BASH_SOURCE[0]}")/../../config.local"
	echo
}

releasePackage() {
	local repo=$1
	local pkgbase=$2
	local arch=$3
	local a
	local p
	local pkgver
	local pkgname

	pushd "${TMP}/svn-packages-copy/${pkgbase}/trunk/" >/dev/null
	xbs release "${repo}" "${arch}" >/dev/null 2>&1
	pkgver=$(. PKGBUILD; get_full_version)
	pkgname=($(. PKGBUILD; echo "${pkgname[@]}"))
	popd >/dev/null
	cp "${pkgdir}/${pkgbase}"/*-"${pkgver}-${arch}"${PKGEXT} "${STAGING}/${repo}/"

	if "${REQUIRE_SIGNATURE}"; then
		for a in "${arch[@]}"; do
			for p in "${pkgname[@]}"; do
				signpkg "${STAGING}/${repo}/${p}-${pkgver}-${a}"${PKGEXT}
			done
		done
	fi
}

checkAnyPackageDB() {
	local repo=$1
	local pkg=$2
	local arch
	local db

	[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}" ] || fail "${PKGPOOL}/${pkg} not found"
	if "${REQUIRE_SIGNATURE}"; then
		[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}.sig" ] || fail "${PKGPOOL}/${pkg}.sig not found"
	fi

	for arch in "${ARCH_BUILD[@]}"; do
		[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}" ] || fail "${repo}/os/${arch}/${pkg} is not a symlink"
		[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}")" == "$(readlink -e "${FTP_BASE}/${PKGPOOL}/${pkg}")" ] \
			|| fail "${repo}/os/${arch}/${pkg} does not link to ${PKGPOOL}/${pkg}"

		if "${REQUIRE_SIGNATURE}"; then
			[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig" ] || fail "${repo}/os/${arch}/${pkg}.sig is not a symlink"
			[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig")" == "$(readlink -e "${FTP_BASE}/${PKGPOOL}/${pkg}.sig")" ] \
				|| fail "${repo}/os/${arch}/${pkg}.sig does not link to ${PKGPOOL}/${pkg}.sig"
		fi

		for db in "${DBEXT}" "${FILESEXT}"; do
			( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" ] \
				&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" -O | grep "${pkg}" &>/dev/null) \
				|| fail "${pkg} not in ${repo}/os/${arch}/${repo}${db%.tar.*}"
		done
	done
	[ -r "${STAGING}/${repo}/${pkg}" ] && fail "${repo}/${pkg} found in staging dir"
	[ -r "${STAGING}/${repo}/${pkg}".sig ] && fail "${repo}/${pkg}.sig found in staging dir"
}

checkAnyPackage() {
	local repo=$1
	local pkg=$2

	checkAnyPackageDB "$repo" "$pkg"

	local pkgbase=$(getpkgbase "${FTP_BASE}/${PKGPOOL}/${pkg}")
	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-any" ] \
		|| fail "svn-packages-copy/${pkgbase}/repos/${repo}-any does not exist"
}

checkPackageDB() {
	local repo=$1
	local pkg=$2
	local arch=$3
	local db

	[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}" ] || fail "${PKGPOOL}/${pkg} not found"
	[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}" ] || fail "${repo}/os/${arch}/${pkg} not a symlink"
	[ -r "${STAGING}/${repo}/${pkg}" ] && fail "${repo}/${pkg} found in staging dir"

	[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}")" == "$(readlink -e "${FTP_BASE}/${PKGPOOL}/${pkg}")" ] \
		|| fail "${repo}/os/${arch}/${pkg} does not link to ${PKGPOOL}/${pkg}"

	if "${REQUIRE_SIGNATURE}"; then
		[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}.sig" ] || fail "${PKGPOOL}/${pkg}.sig not found"
		[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig" ] || fail "${repo}/os/${arch}/${pkg}.sig is not a symlink"
		[ -r "${STAGING}/${repo}/${pkg}.sig" ] && fail "${repo}/${pkg}.sig found in staging dir"

		[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig")" == "$(readlink -e "${FTP_BASE}/${PKGPOOL}/${pkg}.sig")" ] \
			|| fail "${repo}/os/${arch}/${pkg}.sig does not link to ${PKGPOOL}/${pkg}.sig"
	fi

	for db in "${DBEXT}" "${FILESEXT}"; do
		( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" ] \
			&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" -O | grep "${pkg}" &>/dev/null) \
			|| fail "${pkg} not in ${repo}/os/${arch}/${repo}${db%.tar.*}"
	done
}

checkPackage() {
	local repo=$1
	local pkg=$2
	local arch=$3

	checkPackageDB "$repo" "$pkg" "$arch"

	local pkgbase=$(getpkgbase "${FTP_BASE}/${PKGPOOL}/${pkg}")
	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-${arch}" ] \
		|| fail "svn-packages-copy/${pkgbase}/repos/${repo}-${arch} does not exist"
}

checkRemovedPackageDB() {
	local repo=$1
	local pkgbase=$2
	local arch=$3
	local db

	for db in "${DBEXT}" "${FILESEXT}"; do
		( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" ] \
			&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" -O | grep "${pkgbase}" &>/dev/null) \
			&& fail "${pkgbase} should not be in ${repo}/os/${arch}/${repo}${db%.tar.*}"
	done
}

checkRemovedPackage() {
	local repo=$1
	local pkgbase=$2
	local arch=$3

	checkRemovedPackageDB "$repo" "$pkgbase" "$arch"

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-${arch}" ] \
		&& fail "svn-packages-copy/${pkgbase}/repos/${repo}-${arch} should not exist"
}

checkRemovedAnyPackageDB() {
	local repo=$1
	local pkgbase=$2
	local arch
	local db

	for db in "${DBEXT}" "${FILESEXT}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			( [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" ] \
				&& bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" -O | grep "${pkgbase}" &>/dev/null) \
				&& fail "${pkgbase} should not be in ${repo}/os/${arch}/${repo}${db%.tar.*}"
		done
	done
}

checkRemovedAnyPackage() {
	local repo=$1
	local pkgbase=$2

	checkRemovedAnyPackageDB "$repo" "$pkgbase"

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-any" ] \
		&& fail "svn-packages-copy/${pkgbase}/repos/${repo}-any should not exist"
}
