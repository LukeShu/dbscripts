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

getpkgbase() {
	local _base
	_grep_pkginfo() {
		local _ret

		_ret="$(/usr/bin/bsdtar -xOqf "$1" .PKGINFO | grep -m 1 "^${2} = ")"
		echo "${_ret#${2} = }"
	}

	_base="$(_grep_pkginfo "$1" "pkgbase")"
	if [ -z "$_base" ]; then
		_grep_pkginfo "$1" "pkgname"
	else
		echo "$_base"
	fi
}

releasePackage() {
	local repo=$1
	local pkgbase=$2
	local arch=$3
	local a
	local p
	local pkgver
	local pkgname

	if [ ! -d "${TMP}/svn-packages-copy/${pkgbase}/trunk" ]; then
		mkdir -p "${TMP}/svn-packages-copy/${pkgbase}"/{trunk,repos}
		cp "fixtures/${pkgbase}"/* "${TMP}/svn-packages-copy"/${pkgbase}/trunk/
		svn add -q "${TMP}/svn-packages-copy"/${pkgbase}
		svn commit -q -m"initial commit of ${pkgbase}" "${TMP}/svn-packages-copy"
	fi

	pushd "${TMP}/svn-packages-copy/${pkgbase}/trunk/" >/dev/null
	__buildPackage ${arch}
	xbs release "${repo}" "${arch}" >/dev/null 2>&1
	pkgver=$(. PKGBUILD; get_full_version)
	pkgname=($(. PKGBUILD; echo "${pkgname[@]}"))
	cp *-"${pkgver}-${arch}"${PKGEXT} "${STAGING}/${repo}/"
	popd >/dev/null

	if "${REQUIRE_SIGNATURE}"; then
		for a in "${arch[@]}"; do
			for p in "${pkgname[@]}"; do
				signpkg "${STAGING}/${repo}/${p}-${pkgver}-${a}"${PKGEXT}
			done
		done
	fi
}

getPackageNamesFromPackageBase() {
	local pkgbase=$1

	$(. "packages/${pkgbase}/PKGBUILD"; echo ${pkgname[@]})
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
