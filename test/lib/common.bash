#!/hint/bash

. /usr/share/makepkg/util.sh
. "$(dirname "${BASH_SOURCE[0]}")"/../test.conf

die() {
	echo "$*" >&2
	exit 1
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

	for p in "${pkgname[@]}"; do
		for file in "${p}-${pkgver}-${arch}"*; do
			gpg --detach-sign --no-armor --use-agent "$file"
		done
	done
}

setup() {
	local p
	local pkg
	local r
	local a

	TMP="$(mktemp -d)"

	export DBSCRIPTS_CONFIG=${TMP}/config.local
	cat <<eot > "${DBSCRIPTS_CONFIG}"
	FTP_BASE="${TMP}/ftp"
	SVNREPO="file://${TMP}/svn-packages-repo"
	PKGREPOS=('core' 'extra' 'testing')
	PKGPOOL='pool/packages'
	SRCPOOL='sources/packages'
	TESTING_REPO='testing'
	STABLE_REPOS=('core' 'extra')
	CLEANUP_DESTDIR="${TMP}/package-cleanup"
	SOURCE_CLEANUP_DESTDIR="${TMP}/source-cleanup"
	STAGING="${TMP}/staging"
	TMPDIR="${TMP}/tmp"
	CLEANUP_DRYRUN=false
	SOURCE_CLEANUP_DRYRUN=false
eot
	. config

	mkdir -p "${TMP}/"{ftp,tmp,staging,{package,source}-cleanup,svn-packages-{copy,repo}}

	for r in "${PKGREPOS[@]}"; do
		mkdir -p "${TMP}/staging/${r}"
		for a in "${ARCHES[@]}"; do
			mkdir -p "${TMP}/ftp/${r}/os/${a}"
		done
	done
	mkdir -p "${TMP}/ftp/${PKGPOOL}"
	mkdir -p "${TMP}/ftp/${SRCPOOL}"

	svnadmin create "${TMP}/svn-packages-repo"
	svn checkout -q "file://${TMP}/svn-packages-repo" "${TMP}/svn-packages-copy"

	mkdir -p "${TMP}/home/.config/xbs"
	export XDG_CONFIG_HOME="${TMP}/home/.config"
	cat <<eot > "$XDG_CONFIG_HOME/xbs/xbs-abs.conf"
	SVNDIR="${TMP}"
	SVNREPOS=(
		"svn-packages-copy file://${TMP}/svn-packages-repo core extra testing"
	)
	ARCHES=(${ARCH_BUILD[*]})
eot
	echo 'BUILDSYSTEM=abs' > "$XDG_CONFIG_HOME/xbs/xbs.conf"
}

teardown() {
	rm -rf "${TMP}"
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
	xbs release-client "${repo}" "${arch}"
	pkgver=$(. PKGBUILD; get_full_version)
	pkgname=($(. PKGBUILD; echo "${pkgname[@]}"))
	for p in "${pkgname[@]}"; do
		cp "${p}-${pkgver}-${arch}"${PKGEXT}{,.sig} "${STAGING}/${repo}/"
	done
	popd >/dev/null
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
	[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}.sig" ]

	for arch in "${ARCH_BUILD[@]}"; do
		[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}" ]
		[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}")" == "$(readlink -e "${FTP_BASE}/${PKGPOOL}/${pkg}")" ]

		[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig" ]
		[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig")" == "$(readlink -e "${FTP_BASE}/${PKGPOOL}/${pkg}.sig")" ]

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

	[ -r "${FTP_BASE}/${PKGPOOL}/${pkg}.sig" ]
	[ -L "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig" ]
	[ ! -r "${STAGING}/${repo}/${pkg}.sig" ]

	[ "$(readlink -e "${FTP_BASE}/${repo}/os/${arch}/${pkg}.sig")" == "$(readlink -e "${FTP_BASE}/${PKGPOOL}/${pkg}.sig")" ]

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
