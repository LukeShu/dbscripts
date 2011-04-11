#!/usr/bin/python
# -*- coding: utf-8 -*-
from repm.filter import *
import argparse

def make_pending(path_to_db, repo, prefix=config["pending"]):
    """ Determine wich packages are pending for license auditing."""
    filename=prefix + "-" + repo + ".txt"
    try:
        fsock=open(filename, "rw")
        if os.path.isfile(filename):
            pkgs=[pkg for pkg in packages_iterable if pkg["name"] not in
                  listado(filename)]
        fsock.write("\n".join([pkg["name"] + ":" + pkg["license"]
                           for pkg in pkgs]) + "\n")
    except(IOError):
        print("Can't read %s" % filename)
        exit(1)
    finally:
        fsock.close()
    
    if "~" in path_to_db:
        path_to_db=(os.path.expanduser(path_to_db))

    packages_iterable=pkginfo_from_db(path_to_db)
    search = tuple(listado(config["blacklist"]) +
                   listado(config["whitelist"]))
    
    pkgs=[pkg for pkg in packages_iterable
          if "custom" in pkg["license"]
          and pkg["name"] not in search]
    return pkgs

def write_pending(packages_iterable, repo, prefix=config["pending"]):
    """ Write a pending file with the info of the packages """

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Clean a repo db and packages")
    parser.add_argument("-b", "--database", type=str, required=True,
                        help="database to check")
    parser.add_argument("-r", "--repo", type=str, required=True,
                        help="repo of database")
    args=parser.parse_args()

    if args.database and args.repo:
        pkgs=make_pending(args.database)
        write_pending(pkgs, args.repo)
    else:
        parser.print_help()
