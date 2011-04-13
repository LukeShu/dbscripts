#! /usr/bin/python
#-*- encoding: utf-8 -*-
from repm.filter import *
import argparse

def mkpending(path_to_db, repo, prefix=config["pending"]):
    """ Determine wich packages are pending for license auditing."""
    if "~" in path_to_db:
        path_to_db=(os.path.expanduser(path_to_db))

    search = tuple(listado(config["blacklist"]) +
                   listado(config["whitelist"]))
    
    pkgs=list(pkginfo_from_db(path_to_db))

    filename=prefix + "-" + repo + ".txt"
    try:
        fsock=open(filename, "rw")
        pkgs=[pkg for pkg in pkginfo_from_db(path_to_db)
              if pkg["name"] not in listado(filename)]
        for line in fsock.readlines():
            if line:
                pkg=Package()
                pkg["name"]=line.split(":")[0]
                pkg["license"]=":".join(line.split(":")[1:])
                pkgs.append(pkg)
        pkgs=[pkg for pkg in pkgs if pkg["name"] not in search
              and "custom" in pkg["license"]]
        fsock.write("\n".join([pkg["name"] + ":" + pkg["license"]
                               for pkg in pkgs]) + "\n")
    except(IOError):
        raise NonValidFile("Can't read or write %s" % filename)
    finally:
        fsock.close()
    return pkgs

def remove_from_blacklist(path_to_db, blacklisted_names,
                          debug=config["debug"]):
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
    if debug:
        printf(a)
        return pkgs, cmd

def cleanup_nonfree_in_dir(directory, blacklisted_names):
    if "~" in directory:
        directory=(os.path.expanduser(directory))
    pkgs=pkginfo_from_files_in_dir(directory)
    for package in pkgs:
        if package["name"] in blacklisted_names:
            os.remove(package["location"])

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Clean a repo db and packages")
    parser.add_argument("-b", "--database", type=str,
                        help="dabatase to clean")
    parser.add_argument("-d", "--directory", type=str,
                        help="directory to clean")
    args=parser.parse_args()

    if args.database:
        repo=os.path.basename(args.database).split(".")[0]
        pkgs=pkginfo_from_db(args.database)
        remove_from_blacklist(args.database, pkgs,
                              tuple(listado(config["blacklist"]) +
                                    listado(config["pending"] + 
                                            "-" + repo + ".txt")))
        mkpending(args.database, args.repo)

    if args.directory:
        cleanup_nonfree_in_dir(args.directory,
                               listado(config["blacklist"]))

    if not args.directory and not args.database:
        parser.print_help()
