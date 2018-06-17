# Parabola GNU/Linux-libre repository management scripts
## Configuration
* The default configuration can be found in `config`.
* An optional `config.local` may override the default configuration.
* The path and name of the local configuration file can be overridden
  by setting the `DBSCRIPTS_CONFIG` environment variable.
## Overview
The executables that you (might) care about are:

    dbscripts/
    ├── cron-jobs/
    │   ├── db-cleanup                  [Parabola only]
    │   ├── devlist-mailer
    │   ├── ftpdir-cleanup
    │   ├── integrity-check
    │   ├── make_repo_torrents          [Parabola only]
    │   ├── sourceballs
    │   ├── update-web-db               [Arch Linux only]
    │   └── update-web-files-db         [Arch Linux only]
    ├── db-check-nonfree                [Parabola only]
    ├── db-check-package-libraries      [Parabola only]
    ├── db-check-repo-sanity            [Parabola only]
    ├── db-check-unsigned-packages      [Parabola only]
    ├── db-check-unsigned-packages.py   [Parabola only]
    ├── db-import-archlinuxarm-src      [Parabola only]
    ├── db-import-pkg                   [Parabola only]
    ├── db-init                         [Parabola only]
    ├── db-move
    ├── db-remove
    ├── db-repo-add
    ├── db-repo-remove
    ├── db-update
    ├── make_individual_torrent         [Parabola only]
    └── testing2x                       [Arch Linux only]

Ok, now let's talk about what those are.

There are 3 "main" programs:

 - `db-update` : add packages to repositories
 - `db-remove` : remove packages from repositories
 - `db-move`   : move packages from one repository to another

Of course, sometimes things go wrong, and you need to drop to a
lower-level, but you don't want to go all the way down to pacman's
`repo-add`/`repo-remove`.  So, we have:

 - `db-repo-add`
 - `db-repo-remove`

Now, we'd like to be able to check that the repos are all OK, so we
have

 - `cron-jobs/integrity-check`

Instead of enhancing `integrity-check`, Parabola developers have
decided to write multiple stand-alone tools that should probably be
merged into `integrity-check`

 - `db-check-*`

When we remove a package from a repository, it stays in the package
"pool".  We would like to be able to eventually remove packages from
the pool, to reclaim the disk space:

 - `cron-jobs/ftpdir-cleanup`
 - `cron-jobs/db-cleanup`

Both of these programs do the exact same thing.  Parabola developers
decided to write their own from scratch, instead of modifying
`ftpdir-cleanup`.  They should eventually be merged.

But, Parabola doesn't just publish our own packages, we also import
packages from elsewhere:

 - `db-import-*`

Unfortunately, these import scripts fiddle with the repos directly,
rather than calling `db-{update,move,remove}`, and are prone to break
things.

Things that haven't been mentioned yet:

 - `cron-jobs/devlist-mailer`
 - `cron-jobs/make_repo_torrents`
 - `cron-jobs/sourceballs`
 - `db-init`
 - `make_individual_torrent`

## Testing

### Requirements

Packages:

 - `base-devel` package group
 - `bash-bats` package
 - `kcov` package
 - `libretools` package
 - `subversion` package

Other setup:

 - Arrange for `gpg` to sign files using a key that is trusted by the
   pacman keyring.  This is easy if you are already a Parabola
   packager--your PGP key is already trusted by the pacman keyring, as
   it is included in the `parabola-keyring` package.

### Running the tests

The command to run the test suite is

    [BUILDIR=/path/to/cache] [COVERAGE_DIR=/path/to/output] make check[-coverage]

 - The default `BUILDDIR` is `${TMPDIR:-/tmp}/dbscripts-build`;
   packages built as part of test setup are cached here.  This can be
   shared between test suite runs (as libremakepkg isn't the target of
   our tests).
 - Using the `check-coverage` target instead of the `check` target
   also generates a coverage report when running the tests; open
   `${COVERAGE_DIR}/index.html` in your web browser to view the
   results.  The default `COVERAGE_DIR` is `$PWD/coverage`.

### Other testing notes

 - The test suite will use `sudo` to run `unshare -m`, `librechroot`,
   and `libremakepkg`.  It should be safe, but if this makes you
   nervous, run the test suite in a VM or container.

Things outside of the dbscripts directory that are modified:

 - The test suite creates and uses the `librechroot` chroots
   `dbscripts@{any,armv7h,i686,x86_64}`.  It does not ever update
   these after creation or clean these up, and leaves them around to
   speed up future runs.
 - Built packages are cached in `BUILDDIR` (see above).  This
   directory is never cleaned up, and is left around to speed up
   future runs.

You may want to manually clean these up periodically.
