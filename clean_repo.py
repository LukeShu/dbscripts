#! /usr/bin/python
#-*- encoding: utf-8 -*-
from repm.filter import *
import argparse

def remove_from_blacklist(path_to_db, blacklisted_names,
                          debug=config["debug"]):
    """ Check the blacklist and remove packages on the db"""
    
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

    if args.directory:
        cleanup_nonfree_in_dir(args.database, listado(config["blacklist"]))

    if args.database:
        pkgs=pkginfo_from_db(args.database)
        remove_from_blacklist(args.database, pkgs,
                              tuple(listado(config["blacklist"]) +
                                    listado(config["pending"])))
    if not args.directory and not args.database:
        parser.print_help()
