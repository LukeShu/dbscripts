#! /usr/bin/python
#-*- encoding: utf-8 -*-
from repm.filter import *
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="nonfree_in_db",
        description="Cleans nonfree files on repo",)

    parser.add_argument("-k", "--blacklist-file", type=str,
                        help="File containing blacklisted names",
                        required=True,)

    parser.add_argument("-b", "--database", type=str,
                          help="dabatase to clean",
                          required=True,)

    args=parser.parse_args()

    if not (args.blacklist_file and args.database):
        parser.print_help()
        exit(1)

    blacklist=listado(args.blacklist_file)
    pkgs=get_pkginfo_from_db(args.database)

    print(" ".join([pkg["name"] for pkg in pkgs if pkg["name"] in blacklist]))
