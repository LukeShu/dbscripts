 #! /usr/bin/python
#-*- encoding: utf-8 -*-
import commands
import re
from repm.config import *
from repm.pato2 import *

def pkginfo_from_filename(filename):
    """ Generates a Package object with info from a filename,
    filename can be relative or absolute 
    
    Parameters:
    ----------
    filename -> str

    Returns:
    ----------
    pkg -> Package object"""
    pkg = Package()
    pkg["location"] = filename
    fileattrs = os.path.basename(filename).split("-")
    pkg["arch"] = fileattrs.pop(-1).split(".")[0]
    pkg["release"] = fileattrs.pop(-1)
    pkg["version"] = fileattrs.pop(-1)
    pkg["name"] = "-".join(fileattrs)
    return pkg


def pkginfo_from_rsync_output(rsync_output):
    """ Generates a list of packages and versions from an rsync output
    wich uses --list-only and --no-motd options.

    Parameters:
    ----------
    rsync_output -> str          Contains output from rsync
    
    Returns:
    ----------
    package_list -> tuple        Contains Package objects. """
    a=list()

    def package_or_link(line):
        """ Take info out of filename """
        location_field = 4
        pkginfo_from_filename(line.rsplit()[location_field])

    def directory(line):
        pass
               
    options = { "d": directory,
                "l": package_or_link,
                "-": package_or_link}
    
    for line in rsync_output.split("\n"):
        if ".pkg.tar" in line:
            pkginfo_=options[line[0]](line)
            if pkginfo_:
                a.append(pkginfo_)

    return tuple(a)

def pkginfo_from_files_in_dir(directory):
    """ Returns pkginfo from filenames of packages in dir
    wich has .pkg.tar.{xz,gz} on them """

def generate_exclude_list_from_blacklist(packages_iterable, blacklisted_names,
                                         exclude_file=rsync_blacklist, debug=verbose):
    """ Generate an exclude list for rsync 
    
    Parameters:
    ----------
    package_iterable -> list or tuple       Contains Package objects
    blacklisted_names-> list or tuple       Contains blacklisted names
    exclude_file     -> str                 Path to file
    debug            -> bool                If True, file list gets logged

    Output:
    ----------
    None """
    a=list()

    for package in packages_iterable:
        if not isinstance(package, Package):
            raise ValueError(" %s is not a Package object " % package)
        if package["name"] in blacklisted_names:
            a.append(package["location"])

    if debug:
        printf(a)
    
    try:
        fsock = open(exclude_file,"w")
        try:
            fsock.write("\n".join(a))
        finally:
            fsock.close()
    except IOError:
        printf("%s wasnt written" % blacklist_file)

        
if __name__ == "__main__":
    a=run_rsync(rsync_list_command)
    packages=pkginfo_from_rsync_output(a)
    generate_exclude_list_from_blacklist(packages,listado(blacklist))
