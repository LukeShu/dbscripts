#!/hint/bash

. /usr/share/makepkg/util.sh
. "$(dirname "${BASH_SOURCE[0]}")"/../test.conf

__updatePKGBUILD() {
	local pkgrel

	pkgrel=$(. PKGBUILD; expr ${pkgrel} + 1)
	sed "s/pkgrel=.*/pkgrel=${pkgrel}/" -i PKGBUILD
	svn commit -q -m"update pkg to pkgrel=${pkgrel}"
}

__getCheckSum() {
	local result
	result="$(sha1sum "$1")"
	echo "${result%% *}"
}

# Proxy function to check if a file exists. Using [[ -f ... ]] directly is not
# always wanted because we might want to expand bash globs first. This way we
# can pass unquoted globs to __isGlobfile() and have them expanded as function
# arguments before being checked.
#
# This is a copy of db-functions is_globfile
__isGlobfile() {
	[[ -f $1 ]]
}

__buildPackage() {
	local pkgdest=${1:-.}
	local p
	local cache
	local pkgarches
	local tarch
	local pkgfiles

	if [[ -n ${BUILDDIR} ]]; then
		cache=${BUILDDIR}/$(__getCheckSum PKGBUILD)
		if cp -Lv ${cache}/*${PKGEXT}{,.sig} ${pkgdest} 2>/dev/null; then
			return 0
		else
			mkdir -p ${cache}
		fi
	fi

	pkgarches=($(. PKGBUILD; echo ${arch[@]}))
	for tarch in ${pkgarches[@]}; do
		if [ "${tarch}" == 'any' ]; then
			sudo librechroot -n "dbscripts@${tarch}" sync
			mapfile -tO "${#pkgfiles[@]}" pkgfiles < <(PKGDEST=${pkgdest} PKGEXT=${PKGEXT} makepkg --packagelist)
		else
			sudo librechroot -n "dbscripts@${tarch}" -A "$tarch" sync
			mapfile -tO "${#pkgfiles[@]}" pkgfiles < <(PKGDEST=${pkgdest} PKGEXT=${PKGEXT} CARCH=${tarch} makepkg --packagelist)
		fi
		sudo librechroot -n "dbscripts@${tarch}" run bash -c "$(printf '%q ' echo "PKGEXT=${PKGEXT@Q}") >> /etc/makepkg.conf"
		sudo PKGDEST="${pkgdest}" libremakepkg -n "dbscripts@${tarch}"
	done

	for p in ${pkgfiles[@]}; do
		# Manually sign packages as "makepkg --sign" is buggy
		gpg -v --detach-sign --no-armor --use-agent ${p}

		if [[ -n ${BUILDDIR} ]]; then
			cp -Lv ${p}{,.sig} ${cache}/
		fi
	done
}

setup() {
	local p
	local pkg
	local r
	local a
	PKGEXT=".pkg.tar.xz"

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
	ARCHES=(${ARCH_BUILD[*]@Q})
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
	ARCHES=(${ARCH_BUILD[*]@Q})
eot
	echo 'BUILDSYSTEM=abs' > "$XDG_CONFIG_HOME/xbs/xbs.conf"
}

teardown() {
	rm -rf "${TMP}"
}

releasePackage() {
	local repo=$1
	local pkgbase=$2
	local pkgarches
	local tarch

	if [ ! -d "${TMP}/svn-packages-copy/${pkgbase}/trunk" ]; then
		mkdir -p "${TMP}/svn-packages-copy/${pkgbase}"/{trunk,repos}
		cp "fixtures/${pkgbase}"/* "${TMP}/svn-packages-copy"/${pkgbase}/trunk/
		svn add -q "${TMP}/svn-packages-copy"/${pkgbase}
		svn commit -q -m"initial commit of ${pkgbase}" "${TMP}/svn-packages-copy"
	fi

	pushd "${TMP}/svn-packages-copy/${pkgbase}/trunk/"

	__buildPackage "${STAGING}"/${repo}
	pkgarches=($(. PKGBUILD; echo ${arch[@]}))
	for tarch in "${pkgarches[@]}"; do
		xbs release-client "${repo}" "${tarch}"
	done
	popd
}

updatePackage() {
	local pkgbase=$1

	pushd "${TMP}/svn-packages-copy/${pkgbase}/trunk/"
	__updatePKGBUILD
	__buildPackage
	popd
}

updateRepoPKGBUILD() {
	local pkgbase=$1
	local repo=$2
	local arch=$3

	pushd "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-${arch}/"
	__updatePKGBUILD
	popd
}

checkPackageDB() {
	local repo=$1
	local pkgbase=$2
	local db
	local pkgarch
	local repoarch
	local repoarches
	local pkgfile
	local pkgname

	# FIXME: We guess the location of the PKGBUILD used for this repo
	# We cannot read from trunk as __updatePKGBUILD() might have bumped the version
	# and different repos can have different versions of the same package
	local pkgbuildPaths=($(compgen -G "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-*"))
	local pkgbuildPath="${pkgbuildPaths[0]}"
	echo Repo is $repo
	echo pkgbuildPaths = ${pkgbuildPaths[@]}
	echo pkgbuildPath = ${pkgbuildPath}
	ls -ahl ${TMP}/svn-packages-copy/${pkgbase}/repos/
	[ -r "${pkgbuildPath}/PKGBUILD" ]

	local pkgarches=($(. "${pkgbuildPath}/PKGBUILD"; echo ${arch[@]}))
	local pkgnames=($(. "${pkgbuildPath}/PKGBUILD"; echo ${pkgname[@]}))
	local pkgver=$(. "${pkgbuildPath}/PKGBUILD"; get_full_version)

	if [[ ${pkgarches[@]} == any ]]; then
		repoarches=("${ARCHES[@]}")
	else
		repoarches=("${pkgarches[@]}")
	fi

	for pkgarch in ${pkgarches[@]}; do
		for pkgname in ${pkgnames[@]}; do
			pkgfile="${pkgname}-${pkgver}-${pkgarch}${PKGEXT}"

			[ -r "${FTP_BASE}/${PKGPOOL}/${pkgfile}" ]
			[ -r "${FTP_BASE}/${PKGPOOL}/${pkgfile}.sig" ]
			[ ! -r "${STAGING}/${repo}/${pkgfile}" ]
			[ ! -r "${STAGING}/${repo}/${pkgfile}.sig" ]

			for repoarch in "${repoarches[@]}"; do
				# Only 'any' packages can be found in repos of both arches
				if [[ $pkgarch != any ]]; then
					if [[ $pkgarch != ${repoarch} ]]; then
						continue
					fi
				fi

				[ -L "${FTP_BASE}/${repo}/os/${repoarch}/${pkgfile}" ]
				[ "$(readlink -e "${FTP_BASE}/${repo}/os/${repoarch}/${pkgfile}")" == "$(readlink -e "${FTP_BASE}/${PKGPOOL}/${pkgfile}")" ]

				[ -L "${FTP_BASE}/${repo}/os/${repoarch}/${pkgfile}.sig" ]
				[ "$(readlink -e "${FTP_BASE}/${repo}/os/${repoarch}/${pkgfile}.sig")" == "$(readlink -e "${FTP_BASE}/${PKGPOOL}/${pkgfile}.sig")" ]

				for db in "${DBEXT}" "${FILESEXT}"; do
					[ -r "${FTP_BASE}/${repo}/os/${repoarch}/${repo}${db%.tar.*}" ]
					bsdtar -xf "${FTP_BASE}/${repo}/os/${repoarch}/${repo}${db%.tar.*}" -O | grep "${pkgfile%${PKGEXT}}" &>/dev/null
				done
			done
		done
	done
}

checkPackage() {
	local repo=$1
	local pkgbase=$2

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	# TODO: Does not fail if one arch is missing
	compgen -G "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-*" >/dev/null

	checkPackageDB "$repo" "$pkgbase"
}

checkRemovedPackage() {
	local repo=$1
	local pkgbase=$2

	svn up -q "${TMP}/svn-packages-copy/${pkgbase}"
	! compgen -G "${TMP}/svn-packages-copy/${pkgbase}/repos/${repo}-*" >/dev/null

	checkRemovedPackageDB "$repo" "$pkgbase"
}

checkRemovedPackageDB() {
	local repo=$1
	local pkgbase=$2
	local arch
	local db
	local tarch
	local tarches
	local pkgarches
	local pkgnames
	local pkgname

	local pkgbuildPath="${TMP}/svn-packages-copy/${pkgbase}/trunk/PKGBUILD"
	[[ -r ${pkgbuildPath} ]]
	pkgarches=($(. "${pkgbuildPath}"; echo ${arch[@]}))
	pkgnames=($(. "${pkgbuildPath}"; echo ${pkgname[@]}))

	if [[ ${pkgarches[@]} == any ]]; then
		tarches=(${ARCHES[@]})
	else
		tarches=(${pkgarches[@]})
	fi

	for db in "${DBEXT}" "${FILESEXT}"; do
		for tarch in "${tarches[@]}"; do
			if [ -r "${FTP_BASE}/${repo}/os/${tarch}/${repo}${db%.tar.*}" ]; then
				for pkgname in ${pkgnames[@]}; do
					if bsdtar -xf "${FTP_BASE}/${repo}/os/${tarch}/${repo}${db%.tar.*}" -O | grep "${pkgname}" &>/dev/null; then
						return 1
					fi
				done
			fi
		done
	done
}
