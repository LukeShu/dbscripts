#!/hint/bash
set -E

. /usr/share/makepkg/util.sh
. "$(dirname "${BASH_SOURCE[0]}")"/../test.conf

die() {
	echo "$*" >&2
	exit 1
}

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
	gpg --detach-sign --use-agent "${SIGNWITHKEY[@]}" "${@}"
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
		pkgarch=($(. PKGBUILD; echo "${arch[@]}"))
		for a in "${pkgarch[@]}"; do
			__buildPackage "$a"
		done
		popd >/dev/null
	done
}

__buildPackage() {
	local arch=$1
	local pkgver
	local pkgname
	local a
	local p

	pkgname=($(. PKGBUILD; echo "${pkgname[@]}"))
	pkgver=$(. PKGBUILD; get_full_version)

	for p in "${pkgname[@]}"; do
		if [ -f "${p}-${pkgver}-${arch}"${PKGEXT} ]; then
			return 0
		fi
	done

	if [ "${arch}" == 'any' ]; then
		sudo librechroot -n "dbscripts@${arch}" make
	else
		sudo librechroot -n "dbscripts@${arch}" -A "$arch" make
	fi
	sudo libremakepkg -n "dbscripts@${arch}"
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

	cat <<eot > "$(dirname "${BASH_SOURCE[0]}")/../../config.local"
	FTP_BASE="${TMP}/ftp"
	SVNREPO="file://${TMP}/svn-packages-repo"
	PKGREPOS=('core' 'extra' 'testing')
	PKGPOOL='pool/packages'
	SRCPOOL='pool/sources'
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

	[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}" ]
	if "${REQUIRE_SIGNATURE}"; then
		[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}.sig" ]
	fi

	for arch in "${ARCH_BUILD[@]}"; do
		[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}" ]
		[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}")" == "$(readlink -e "${FTP_BASE}/${PKGPOOL}/${pkg}")" ]

		if "${REQUIRE_SIGNATURE}"; then
			[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig" ]
			[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig")" == "$(readlink -e "${FTP_BASE}/${PKGPOOL}/${pkg}.sig")" ]
		fi

		for db in "${DBEXT}" "${FILESEXT}"; do
			if [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" ]; then
				bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" -O | grep "${pkg}" &>/dev/null
			fi
		done
	done
	[ ! -r "${STAGING}/${repo}/${pkg}" ]
	[ ! -r "${STAGING}/${repo}/${pkg}".sig ]
}

checkAnyPackage() {
	local repo=$1
	local pkg=$2

	checkAnyPackageDB "$repo" "$pkg"

	local pkgbase=$(getpkgbase "${FTP_BASE}/${PKGPOOL}/${pkg}")
	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-any" ]
}

checkPackageDB() {
	local repo=$1
	local pkg=$2
	local arch=$3
	local db

	[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}" ]
	[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}" ]
	[ ! -r "${STAGING}/${repo}/${pkg}" ]

	[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}")" == "$(readlink -e "${FTP_BASE}/${PKGPOOL}/${pkg}")" ]

	if "${REQUIRE_SIGNATURE}"; then
		[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}.sig" ]
		[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig" ]
		[ ! -r "${STAGING}/${repo}/${pkg}.sig" ]

		[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig")" == "$(readlink -e "${FTP_BASE}/${PKGPOOL}/${pkg}.sig")" ]
	fi

	for db in "${DBEXT}" "${FILESEXT}"; do
		if [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" ]; then
			bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" -O | grep "${pkg}" &>/dev/null
		fi
	done
}

checkPackage() {
	local repo=$1
	local pkg=$2
	local arch=$3

	checkPackageDB "$repo" "$pkg" "$arch"

	local pkgbase=$(getpkgbase "${FTP_BASE}/${PKGPOOL}/${pkg}")
	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-${arch}" ]
}

checkRemovedPackageDB() {
	local repo=$1
	local pkgbase=$2
	local arch=$3
	local db

	for db in "${DBEXT}" "${FILESEXT}"; do
		if [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" ]; then
			! bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" -O | grep "${pkgbase}" &>/dev/null
		fi
	done
}

checkRemovedPackage() {
	local repo=$1
	local pkgbase=$2
	local arch=$3

	checkRemovedPackageDB "$repo" "$pkgbase" "$arch"

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ ! -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-${arch}" ]
}

checkRemovedAnyPackageDB() {
	local repo=$1
	local pkgbase=$2
	local arch
	local db

	for db in "${DBEXT}" "${FILESEXT}"; do
		for arch in "${ARCH_BUILD[@]}"; do
			if [ -r "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" ]; then
				! bsdtar -xf "${FTP_BASE}/${repo}/os/${arch}/${repo}${db%.tar.*}" -O | grep "${pkgbase}" &>/dev/null
			fi
		done
	done
}

checkRemovedAnyPackage() {
	local repo=$1
	local pkgbase=$2

	checkRemovedAnyPackageDB "$repo" "$pkgbase"

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	[ ! -d "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-any" ]
}
