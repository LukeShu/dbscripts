load ../lib/common

httpserver() {
	read -r verb path version || exit
	if [[ $verb != GET ]]; then
		printf "HTTP/1.1 405 Method Not Allowed\r\nContent-Type: text/plain\r\nContent-length: 0\r\n\r\n"
		exit
	fi
	path="$(cd / && realpath -ms "$path")"
	if ! [[ -f "$1/$path" ]]; then
		printf "HTTP/1.1 404 Not found\r\nContent-Type: text/plain\r\nContent-length: 0\r\n\r\n"
		exit
	fi
	printf "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-length: %d\r\n\r\n" $(stat -L -c %s "$1/$path")
	cat "$1/$path"
}

eval "__common_$(declare -f setup)"
setup() {
	__common_setup

	# Set up rsync server
	cat <<-eot >"${TMP}/rsyncd.conf"
		use chroot = no
		[rsyncd]
		  path = ${TMP}/rsyncd
	eot
	local rsyncport
	rsyncport=$(./lib/runserver "$TMP/rsyncd.pid" \
		rsync --daemon --config "${TMP}/rsyncd.conf")

	# Set up rsync contents
	mkdir -p -- "${TMP}/rsyncd/archlinux/core/os/x86_64"
	touch -- "${TMP}/rsyncd/archlinux/core/os/x86_64/core.db.tar.gz"
	ln -s core.db.tar.gz "${TMP}/rsyncd/archlinux/core/os/x86_64/core.db"
	mkdir -p -- "${TMP}/rsyncd/archlinux"/{pool,sources}/{packages,community}
	date +%s > "${TMP}/rsyncd/archlinux/lastupdate"
	date +%s > "${TMP}/rsyncd/archlinux/lastsync"

	mkdir -p -- "${TMP}/rsyncd/archlinux32/i686/core"
	touch -- "${TMP}/rsyncd/archlinux32/i686/core/core.db.tar.gz"
	ln -s core.db.tar.gz "${TMP}/rsyncd/archlinux32/i686/core/core.db"
	date +%s > "${TMP}/rsyncd/archlinux32/lastupdate"
	date +%s > "${TMP}/rsyncd/archlinux32/lastsync"

	mkdir -p -- "${TMP}/rsyncd/archlinuxarm/armv7h/core"
	touch -- "${TMP}/rsyncd/archlinuxarm/armv7h/core/core.db.tar.gz"
	ln -s core.db.tar.gz "${TMP}/rsyncd/archlinuxarm/armv7h/core/core.db"
	date +%s > "${TMP}/rsyncd/archlinuxarm/lastupdate"
	date +%s > "${TMP}/rsyncd/archlinuxarm/lastsync"

	# Configure db-import to use that rsyncd server
	cat <<-eot >"${TMP}/db-import-archlinux.local.conf"
		ARCHTAGS=('core-x86_64')
		ARCHMIRROR=rsync://localhost:${rsyncport@Q}/rsyncd/archlinux/
	eot
	cat <<-eot >"${TMP}/db-import-archlinux32.local.conf"
		ARCHTAGS=('core-i686')
		ARCHMIRROR=rsync://localhost:${rsyncport@Q}/rsyncd/archlinux32/
	eot
	cat <<-eot >"${TMP}/db-import-archlinuxarm.local.conf"
		ARCHTAGS=('core-armv7h')
		ARCHMIRROR=rsync://localhost:${rsyncport@Q}/rsyncd/archlinuxarm/
	eot

	# Set up HTTP server
	local httpport
	httpport=$(./lib/runserver "$TMP/httpd.pid" \
		bash -c "$(declare -f httpserver); httpserver \"\$@\"" -- "$TMP/httpd")

	# Set up HTTP contents
	mkdir -- "$TMP/httpd"
	cat <<-eot >"$TMP/httpd/blacklist.txt"
		slavery:freedom:fsf:slavekit:Obviously
	eot

	# Configure db-import to use that HTTP server
	mkdir "$XDG_CONFIG_HOME"/libretools
	cat <<-eot >"$XDG_CONFIG_HOME"/libretools/libretools.conf
		BLACKLIST=http://localhost:${httpport@Q}/blacklist.txt
	eot

	# Set up repo contents
	mkdir -p -- "${TMP}/ftp/core/os"/{x86_64,i686,armv7h}
	touch -- "${TMP}"/ftp/core/os/{x86_64,i686,armv7h}/core.db.tar.gz
	ln -s core.db.tar.gz "${TMP}/ftp/core/os/x86_64/core.db"
	ln -s core.db.tar.gz "${TMP}/ftp/core/os/i686/core.db"
	ln -s core.db.tar.gz "${TMP}/ftp/core/os/armv7h/core.db"
	mkdir -p -- "${TMP}/ftp"/{pool,sources}/{packages,community,archlinux32,alarm}
	date +%s > "${TMP}/ftp/lastupdate"
	date +%s > "${TMP}/ftp/lastsync"
}
eval "__common_$(declare -f teardown)"
teardown() {
	xargs -a "${TMP}/httpd.pid" kill --
	xargs -a "${TMP}/rsyncd.pid" kill --
	__common_teardown
}

######################################################################

# Run the command in a new mount namespace with /tmp remounted
# read-only, but with $TMP (which might be under /tmp) still writable.
#
# Arguments are passed as arguments to `sudo`.
__withRoTmp() {
	local mount="mount -o bind ${TMP@Q}{,} && mount -o bind,remount,ro /tmp{,}"
	local env=(
		"DBIMPORT_CONFIG=${DBIMPORT_CONFIG}"
		"DBSCRIPTS_CONFIG=${DBSCRIPTS_CONFIG}"
		"XDG_CONFIG_HOME=${XDG_CONFIG_HOME}"
	)
	sudo -- unshare -m -- sh -c "${mount} && sudo -u ${USER@Q} ${env[*]@Q} \$@" -- "$@"
}

__db-import-pkg() {
	local ret=0
	# Since common.bash->config.local sets TMPDIR=${TMP}/tmp,
	# TMPDIR is necessarily != /tmp.
	# Which means that if we try to write anything directly under /tmp,
	# then we are erroneously disregarding TMPDIR.
	# So, make /tmp read-only to make that be an error.
	__withRoTmp db-import-pkg "$@" || ret=$?
	# Verify that it cleaned up after itself and TMPDIR is empty
	find "$TMPDIR" -mindepth 1 | diff - /dev/null
	return $ret
}

# releaseImportedPackage PKGBASE ARCH DBFILE [POOLDIR]
#
# This is different from common.bash:releasePackage because
# - it doesn't mess with SVN
# - it adds the package to the .db file
__releaseImportedPackage() {
	local pkgbase=$1
	local arch=$2
	local dbfile=$3
	local pooldir=$4
	local repodir="${dbfile%/*}"
	local dir restore pkgfiles pkgfile pkgs

	dir="$TMP/import-build/$pkgbase"
	if ! [[ -d "$dir" ]]; then
		mkdir -p -- "$dir"
		cp -t "$dir" -- "fixtures/${pkgbase}"/*
	fi
	pushd "$dir"
	__buildPackage
	restore="$(shopt -p nullglob || true)"
	shopt -s nullglob
	pkgfiles=(*-{"$arch",any}$PKGEXT{,.sig})
	$restore
	popd

	mkdir -p "$repodir"
	if [[ -z $pooldir ]]; then
		mv -t "$repodir" -- "${pkgfiles[@]/#/"$dir/"}"
	else
		mkdir -p "$pooldir"
		mv -t "$pooldir" -- "${pkgfiles[@]/#/"$dir/"}"
		ln -sr -t "$repodir" -- "${pkgfiles[@]/#/"$pooldir/"}"
	fi

	pushd "$repodir"
	pkgs=()
	for pkgfile in "${pkgfiles[@]}"; do
		if [[ "$pkgfile" = *.sig ]]; then
			continue
		fi
		pkgs+=("$pkgfile")
	done
	repo-add -q "${dbfile##*/}" "${pkgs[@]}"
	popd
}

__updateImportedPackage() {
	pushd "$TMP/import-build/$1"
	local pkgrel
	pkgrel=$(. PKGBUILD; expr ${pkgrel} + 1)
	sed "s/pkgrel=.*/pkgrel=${pkgrel}/" -i PKGBUILD
	popd
}

__isLinkTo() {
	[[ -L $1 ]]
	[[ $1 -ef $2 ]]
}

__doesNotExist() {
	local file
	for file in "$@"; do
		if stat "$file" 2>/dev/null; then
			echo "TEST ERROR: File shouldn't exist, but does: $file"
			return 1
		fi
	done
}

######################################################################

@test "import no blacklisted packages (x86_64)" {
	__releaseImportedPackage slavery      x86_64 "$TMP/rsyncd/archlinux/core/os/x86_64/core.db.tar.gz" "$TMP/rsyncd/archlinux/pool/packages"
	__releaseImportedPackage pkg-simple-c x86_64 "$TMP/rsyncd/archlinux/core/os/x86_64/core.db.tar.gz" "$TMP/rsyncd/archlinux/pool/packages"

	DBIMPORT_CONFIG="${TMP}/db-import-archlinux.local.conf" __db-import-pkg packages

	__isLinkTo "$TMP/ftp/core/os/x86_64/pkg-simple-c-1-1-x86_64.pkg.tar.xz" "$TMP/ftp/pool/packages/pkg-simple-c-1-1-x86_64.pkg.tar.xz"
	__doesNotExist "$TMP"/ftp/{core/os/x86_64,pool/packages,sources/packages}/slavery-*
}

@test "import no blacklisted packages (i686)" {
	__releaseImportedPackage slavery      i686 "$TMP/rsyncd/archlinux32/i686/core/core.db.tar.gz"
	__releaseImportedPackage pkg-simple-c i686 "$TMP/rsyncd/archlinux32/i686/core/core.db.tar.gz"

	DBIMPORT_CONFIG="${TMP}/db-import-archlinux32.local.conf" __db-import-pkg archlinux32

	__isLinkTo "$TMP/ftp/core/os/i686/pkg-simple-c-1-1-i686.pkg.tar.xz" "$TMP/ftp/pool/archlinux32/pkg-simple-c-1-1-i686.pkg.tar.xz"
	__doesNotExist "$TMP"/ftp/{core/os/i686,pool/archlinux32,sources/archlinux32}/slavery-*
}

@test "import no blacklisted packages (armv7h)" {
	__releaseImportedPackage slavery      armv7h "$TMP/rsyncd/archlinuxarm/armv7h/core/core.db.tar.gz"
	__releaseImportedPackage pkg-simple-c armv7h "$TMP/rsyncd/archlinuxarm/armv7h/core/core.db.tar.gz"

	DBIMPORT_CONFIG="${TMP}/db-import-archlinuxarm.local.conf" __db-import-pkg archlinuxarm

	__isLinkTo "$TMP/ftp/core/os/armv7h/pkg-simple-c-1-1-armv7h.pkg.tar.xz" "$TMP/ftp/pool/alarm/pkg-simple-c-1-1-armv7h.pkg.tar.xz"
	__doesNotExist "$TMP"/ftp/{core/os/alarm,pool/alarm,sources/alarm}/slavery-*
}

@test "import DBs with no blacklisted packages" {
	__releaseImportedPackage pkg-simple-c x86_64 "$TMP/rsyncd/archlinux/core/os/x86_64/core.db.tar.gz" "$TMP/rsyncd/archlinux/pool/packages"

	DBIMPORT_CONFIG="${TMP}/db-import-archlinux.local.conf" __db-import-pkg packages

	__isLinkTo "$TMP/ftp/core/os/x86_64/pkg-simple-c-1-1-x86_64.pkg.tar.xz" "$TMP/ftp/pool/packages/pkg-simple-c-1-1-x86_64.pkg.tar.xz"
}

@test "import updated packages" {
	__releaseImportedPackage slavery      x86_64 "$TMP/rsyncd/archlinux/core/os/x86_64/core.db.tar.gz" "$TMP/rsyncd/archlinux/pool/packages"
	__releaseImportedPackage pkg-simple-c x86_64 "$TMP/rsyncd/archlinux/core/os/x86_64/core.db.tar.gz" "$TMP/rsyncd/archlinux/pool/packages"

	DBIMPORT_CONFIG="${TMP}/db-import-archlinux.local.conf" __db-import-pkg packages

	__isLinkTo "$TMP/ftp/core/os/x86_64/pkg-simple-c-1-1-x86_64.pkg.tar.xz" "$TMP/ftp/pool/packages/pkg-simple-c-1-1-x86_64.pkg.tar.xz"

	__updateImportedPackage pkg-simple-c
	__releaseImportedPackage pkg-simple-c x86_64 "$TMP/rsyncd/archlinux/core/os/x86_64/core.db.tar.gz" "$TMP/rsyncd/archlinux/pool/packages"

	DBIMPORT_CONFIG="${TMP}/db-import-archlinux.local.conf" __db-import-pkg packages

	__isLinkTo "$TMP/ftp/core/os/x86_64/pkg-simple-c-1-2-x86_64.pkg.tar.xz" "$TMP/ftp/pool/packages/pkg-simple-c-1-2-x86_64.pkg.tar.xz"
}

@test "import .db files as 0664 (x86_64)" {
	__releaseImportedPackage slavery      x86_64 "$TMP/rsyncd/archlinux/core/os/x86_64/core.db.tar.gz" "$TMP/rsyncd/archlinux/pool/packages"
	__releaseImportedPackage pkg-simple-c x86_64 "$TMP/rsyncd/archlinux/core/os/x86_64/core.db.tar.gz" "$TMP/rsyncd/archlinux/pool/packages"

	DBIMPORT_CONFIG="${TMP}/db-import-archlinux.local.conf" __db-import-pkg packages

	__isLinkTo "$TMP/ftp/core/os/x86_64/pkg-simple-c-1-1-x86_64.pkg.tar.xz" "$TMP/ftp/pool/packages/pkg-simple-c-1-1-x86_64.pkg.tar.xz"
	__doesNotExist "$TMP"/ftp/{core/os/x86_64,pool/packages,sources/packages}/slavery-*
	[[ "$(stat -c '%a' -- "$TMP/ftp/core/os/x86_64/core.db.tar.gz")" = 664 ]]
}

@test "import .db files as 0664 (i686)" {
	__releaseImportedPackage slavery      i686 "$TMP/rsyncd/archlinux32/i686/core/core.db.tar.gz"
	__releaseImportedPackage pkg-simple-c i686 "$TMP/rsyncd/archlinux32/i686/core/core.db.tar.gz"

	DBIMPORT_CONFIG="${TMP}/db-import-archlinux32.local.conf" __db-import-pkg archlinux32

	__isLinkTo "$TMP/ftp/core/os/i686/pkg-simple-c-1-1-i686.pkg.tar.xz" "$TMP/ftp/pool/archlinux32/pkg-simple-c-1-1-i686.pkg.tar.xz"
	__doesNotExist "$TMP"/ftp/{core/os/i686,pool/archlinux32,sources/archlinux32}/slavery-*
	stat -- "$TMP/ftp/core/os/i686/core.db.tar.gz"
	[[ "$(stat -c '%a' -- "$TMP/ftp/core/os/i686/core.db.tar.gz")" = 664 ]]
}

@test "import .db files as 0664 (armv7h)" {
	__releaseImportedPackage slavery      armv7h "$TMP/rsyncd/archlinuxarm/armv7h/core/core.db.tar.gz"
	__releaseImportedPackage pkg-simple-c armv7h "$TMP/rsyncd/archlinuxarm/armv7h/core/core.db.tar.gz"

	DBIMPORT_CONFIG="${TMP}/db-import-archlinuxarm.local.conf" __db-import-pkg archlinuxarm

	__isLinkTo "$TMP/ftp/core/os/armv7h/pkg-simple-c-1-1-armv7h.pkg.tar.xz" "$TMP/ftp/pool/alarm/pkg-simple-c-1-1-armv7h.pkg.tar.xz"
	__doesNotExist "$TMP"/ftp/{core/os/armv7h,pool/alarm,sources/alarm}/slavery-*
	stat -- "$TMP/ftp/core/os/armv7h/core.db.tar.gz"
	[[ "$(stat -c '%a' -- "$TMP/ftp/core/os/armv7h/core.db.tar.gz")" = 664 ]]
}

@test "import fully-masked upstream" {
	__releaseImportedPackage pkg-any-a x86_64 "$TMP/rsyncd/archlinux/core/os/x86_64/core.db.tar.gz" "$TMP/rsyncd/archlinux/pool/packages"
	__releaseImportedPackage pkg-any-a i686   "$TMP/rsyncd/archlinux32/i686/core/core.db.tar.gz"
	__releaseImportedPackage pkg-any-a armv7h "$TMP/rsyncd/archlinuxarm/armv7h/core/core.db.tar.gz"

	DBIMPORT_CONFIG="${TMP}/db-import-archlinux.local.conf" __db-import-pkg packages
	DBIMPORT_CONFIG="${TMP}/db-import-archlinux32.local.conf" __db-import-pkg archlinux32
	DBIMPORT_CONFIG="${TMP}/db-import-archlinuxarm.local.conf" __db-import-pkg archlinuxarm

	__isLinkTo "$TMP/ftp/core/os/x86_64/pkg-any-a-1-1-any.pkg.tar.xz" "$TMP/ftp/pool/packages/pkg-any-a-1-1-any.pkg.tar.xz"
	__isLinkTo "$TMP/ftp/core/os/i686/pkg-any-a-1-1-any.pkg.tar.xz"   "$TMP/ftp/pool/packages/pkg-any-a-1-1-any.pkg.tar.xz"
	__isLinkTo "$TMP/ftp/core/os/armv7h/pkg-any-a-1-1-any.pkg.tar.xz" "$TMP/ftp/pool/packages/pkg-any-a-1-1-any.pkg.tar.xz"
}

@test "import errors on pkgpool selection failures" {
	# pkg-simple-c is just to make sure that the "fully-masked
	# upstream" bug isn't being tested here
	__releaseImportedPackage pkg-any-a x86_64 "$TMP/rsyncd/archlinux/core/os/x86_64/core.db.tar.gz" "$TMP/rsyncd/archlinux/pool/packages"
	__releaseImportedPackage pkg-simple-c x86_64 "$TMP/rsyncd/archlinux/core/os/x86_64/core.db.tar.gz" "$TMP/rsyncd/archlinux/pool/packages"
	__updateImportedPackage pkg-any-a
	__releaseImportedPackage pkg-any-a x86_64 "$TMP/rsyncd/archlinux/core/os/x86_64/core.db.tar.gz" "$TMP/rsyncd/archlinux/pool/packages"
	DBIMPORT_CONFIG="${TMP}/db-import-archlinux.local.conf" __db-import-pkg packages
	__isLinkTo "$TMP/ftp/core/os/x86_64/pkg-any-a-1-2-any.pkg.tar.xz" "$TMP/ftp/pool/packages/pkg-any-a-1-2-any.pkg.tar.xz"

	# This assumes that a package nested too deelply under /pool/
	# is filtered from being downloaded, but isn't found when
	# poolifying.
	mkdir -- "$TMP/ftp/pool/nested"
	mv -T -- "$TMP/ftp/pool/packages" "$TMP/ftp/pool/nested/packages"
	__releaseImportedPackage pkg-any-a i686 "$TMP/rsyncd/archlinux32/i686/core/core.db.tar.gz"
	__releaseImportedPackage pkg-simple-c i686 "$TMP/rsyncd/archlinux32/i686/core/core.db.tar.gz"

	local status=0
	DBIMPORT_CONFIG="${TMP}/db-import-archlinux32.local.conf" __db-import-pkg archlinux32 || status=$?
	[[ $status != 0 ]]
	__doesNotExist "$TMP/ftp/core/os/i686/pkg-any-a-1-2-any.pkg.tar.xz"
}

@test "import arch=any packages with sub-pkgrel" {
	# This is modeled after the situation with 'asp' and 'asp32'

	__releaseImportedPackage pkg-any64 x86_64 "$TMP/rsyncd/archlinux/core/os/x86_64/core.db.tar.gz" "$TMP/rsyncd/archlinux/pool/packages"
	DBIMPORT_CONFIG="${TMP}/db-import-archlinux.local.conf" __db-import-pkg packages
	__isLinkTo "$TMP/ftp/core/os/x86_64/pkg-any-2-1-any.pkg.tar.xz" "$TMP/ftp/pool/packages/pkg-any-2-1-any.pkg.tar.xz"

	__releaseImportedPackage pkg-any32 i686 "$TMP/rsyncd/archlinux32/i686/core/core.db.tar.gz"
	DBIMPORT_CONFIG="${TMP}/db-import-archlinux32.local.conf" __db-import-pkg archlinux32
	__isLinkTo "$TMP/ftp/core/os/i686/pkg-any-1-1.2-any.pkg.tar.xz" "$TMP/ftp/pool/archlinux32/pkg-any-1-1.2-any.pkg.tar.xz"
}
