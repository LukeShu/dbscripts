# Parabola GNU/Linux-libre repository management scripts
## Configuration
* The default configuration can be found in `config`.
* An optional `config.local` may override the default configuration.
* The path and name of the local configuration file can be overridden by setting the `DBSCRIPTS_CONFIG` environment variable.
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
    ├── db-check-nonfree-in-db          [Parabola only]
    ├── db-check-package-libraries      [Parabola only]
    ├── db-check-repo-sanity            [Parabola only]
    ├── db-check-unsigned-packages      [Parabola only]
    ├── db-check-unsigned-packages.py   [Parabola only]
    ├── db-import-archlinux-any-to-ours [Parabola only]
    ├── db-import-archlinux-pkg         [Parabola only]
    ├── db-import-archlinux-src         [Parabola only]
    ├── db-import-archlinuxarm-pkg      [Parabola only]
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

Instead of enhancing `integrity-check`, Parabola developers have decided
to write multiple stand-alone tools that should probably be merged
into `integrity-check`

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

 - `db-import-${source}*`

Unfortunately, these scripts are horribly duct-taped together and are
aweful.  I hate them.

Things that haven't been mentioned yet:

 - `cron-jobs/devlist-mailer`
 - `cron-jobs/make_repo_torrents`
 - `cron-jobs/sourceballs`
 - `db-init`
 - `make_individual_torrent`
