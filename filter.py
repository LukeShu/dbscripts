#! /usr/bin/python
#-*- encoding: utf-8 -*-
import commands
import os
import re
from repm.config import *
from repm.pato2 import *

rsync_list_command="rsync -av --no-motd --list-only "

def generate_rsync_command(base_command, dir_list, destdir=repodir, mirror_name=mirror,
                           mirror_path=mirrorpath, blacklist_file=False):
    """ Generates an rsync command for executing it by combining all parameters.
    
    Parameters:
    ----------
    base_command   -> str
    mirror_name    -> str
    mirror_path    -> str
    dir_list       -> list or tuple
    destdir        -> str                  Must be a dir
    blacklist_file -> False or str         File must exist
    
    Return:
    ----------
    rsync_command -> str """
    from os.path import isfile, isdir

    if blacklist_file and not isfile(blacklist_file):
        print(blacklist_file + " is not a file")
        raise NonValidFile

    if not os.path.isdir(destdir):
        print(destdir + " is not a directory")
        raise NonValidDir

    dir_list="{" + ",".join(dir_list) + "}"

    if blacklist_file:
        return " ".join((base_command, "--exclude-from-file="+blacklist_file,
                        mirror_name + mirror_path + dir_list, destdir))
    return " ".join((base_command, mirror_name + mirror_path + dir_list, destdir))

def run_rsync(base_for_rsync=rsync_list_command, dir_list_for_rsync=(repo_list + dir_list),
              debug=verbose):
    """ Runs rsync and gets returns it's output """
    cmd = str(generate_rsync_command(rsync_list_command, (repo_list + dir_list)))
    if debug:
        printf("rsync_command" + cmd)
    return commands.getoutput(cmd)

def get_file_list_from_rsync_output(rsync_output):
    """ Generates a list of packages and versions from an rsync output using --list-only --no-motd.

    Parameters:
    ----------
    rsync_output -> str containing output from rsync
    
    Returns:
    ----------
    package_list -> tuple of Package objects. """
    a=list()

    def directory(line):
        pass

    def package_or_link(line):
        """ Take info out of filename """
        location_field = 4
        pkg = Package()
        pkg["location"] = line.rsplit()[location_field]
        fileattrs = pkg["location"].split("/")[-1].split("-")
        pkg["arch"] = fileattrs.pop(-1).split(".")[0]
        pkg["release"] = fileattrs.pop(-1)
        pkg["version"] = fileattrs.pop(-1)
        pkg["name"] = "-".join(fileattrs)
        return pkg
                
    options = { "d": directory,
                "l": package_or_link,
                "-": package_or_link}
    
    for line in rsync_output.split("\n"):
        if ".pkg.tar.gz" or ".pkg.tar.xz" in line:
           pkginfo=options[line[0]](line)
           if pkginfo:
               a.append(pkginfo)

    return tuple(a)

