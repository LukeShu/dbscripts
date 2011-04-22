#! /usr/bin/python
#-*- encoding: utf-8 -*-
from repm.filter import *
import argparse

def mkpending(packages_iterable, pending_file, blacklisted_names,
              whitelisted_names):
    """ Determine wich packages are pending for license auditing."""
    search = tuple(blacklisted_names +
                   whitelisted_names)
    
    try:
        fsock=open(pending_file, "r")
        pkgs=[pkg for pkg in packages_iterable
              if pkg["name"] not in listado(pending_file)]
        for line in fsock.readlines():
            if line:
                pkg=Package()
                pkg["name"]=line.split(":")[0]
                pkg["license"]=":".join(line.split(":")[1:])
                pkgs.append(pkg)
        pkgs=[pkg for pkg in pkgs if pkg["name"] not in search
              and "custom" in pkg["license"]]
        fsock=open(pending_file, "w")
        fsock.write("\n".join([pkg["name"] + ":" + pkg["location"] + 
                               ":" + pkg["license"]
                               for pkg in pkgs]) + "\n")
        fsock.close()
    except(IOError):
        printf("Can't read or write %s" % pending_file)
    return pkgs

def remove_from_blacklist(path_to_db, blacklisted_names):
    """ Check the blacklist and remove packages on the db"""
    if "~" in path_to_db:
        path_to_db=(os.path.expanduser(path_to_db))

    pkgs=[pkg for pkg in pkginfo_from_db(path_to_db) if
          pkg["name"] in blacklisted_names]
    if pkgs:
        lista=" ".join(pkgs)
        cmd =  "repo-remove " + path_to_db + " " + lista
        printf(cmd)
        a = check_output(cmd)
    return pkgs

def cleanup_nonfree_in_dir(directory, blacklisted_names):
    if "~" in directory:
        directory=(os.path.expanduser(directory))
    pkglist=list()
    pkgs=pkginfo_from_files_in_dir(directory)
    for package in pkgs:
        if package["name"] in blacklisted_names:
            os.remove(package["location"])
            pkglist.append(package)
    return pkglist

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="clean_repo",
        description="Clean a repo db and packages",)

    parser.add_argument("-k", "--blacklist-file", type=str,
                        help="File containing blacklisted names",
                        required=True,)

    group_dir=parser.add_argument_group("Clean non-free packages in dir")
    group_dir.add_argument("-d", "--directory", type=str,
                        help="directory to clean")

    group_db=parser.add_argument_group("Clean non-free packages in db",
                                       "All these arguments need to be specified for db cleaning:")
    group_db.add_argument("-b", "--database", type=str,
                          help="dabatase to clean")
    group_db.add_argument("-p", "--pending-file", type=str,
                          help="File in which to write pending list")
    group_db.add_argument("-w", "--whitelist-file", type=str,
                          help="File containing whitelisted names")

    args=parser.parse_args()

    if args.database and not (args.pending_file and args.whitelist_file):
        parser.print_help()
        exit(1)

    blacklisted=listado(args.blacklist_file)

    if args.database:
        whitelisted=listado(args.whitelist_file)
        pkgs=pkginfo_from_db(args.database)
        pending_names=[pkg["name"] for pkg in
            mkpending(pkgs, args.pending_file,
                      blacklisted, whitelisted)]

    if args.directory and args.database:
        cleanup_nonfree_in_dir(args.directory, (blacklisted + pending_names))
    elif args.directory:
        cleanup_nonfree_in_dir(args.directory, blacklisted)
    
