#!/usr/bin/python
# -*- coding: utf-8 -*-
from user import home
import commands
import os

time__ = commands.getoutput("date +%Y%m%d-%H:%M")

# Mirror Parameters
mirror = "mirrors.eu.kernel.org"
mirrorpath = "::mirrors/archlinux"

# Directories and files

## Optionals
path   = home + "/parabolagnulinux.org"
docs   = path + "/docs"
logdir = path + "/log"

## Must be defined
logname= logdir + "/" + time__ + "-repo-maintainer.log"
freedir= path + "/free/"
repodir= path + "/repo"
tmp    = home + "/tmp"
archdb = tmp  + "/db"

free_path= path + "/free/"

# Repo, arch, and other folders to use for repo
# This are tuples, so **always keep a comma before closing parenthesis **
repo_list = ("core", "extra", "community", "testing", "community-testing", "multilib",)
dir_list  = ("pool",)
arch_list = ("i686", "x86_64",)
other     = ("any",)

# Output
output    = True
verbose   = True

# Files
blacklist = docs + "/blacklist.txt"
whitelist = docs + "/whitelist.txt"
pending   = docs + "/pending"
rsync_blacklist = docs + "/rsyncBlacklist"

# Rsync commands

rsync_list_command="rsync -a --no-motd --list-only "
rsync_update_command="rsync -av --delay-updates "

# Classes and Exceptions
class NonValidFile(ValueError): pass
class NonValidDir(ValueError): pass
class NonValidCommand(ValueError): pass

class Package:
    """ An object that has information about a package. """
    package_info=dict()
    
    def __init__(self):
        self.package_info={ "name"    : False,
                            "version" : False,
                            "release" : False,
                            "arch"    : False,
                            "license" : False,
                            "location": False,
                            "depends" : False,}
        
    def __setitem__(self, key, item):
        if key in self.package_info.keys():
            return self.package_info.__setitem__(key, item)
        else:
            raise ValueError("Package has no %s attribute" % key)

    def __getitem__(self, key):
        return self.package_info.__getitem__(key)
    
    def __unicode__(self):
        return str(self.package_info)

    def __repr__(self):
        return str(self.package_info)

    def __eq__(self,x):
        if not isinstance(x, Package):
            return False
        for key in self.package_info.keys():
                if x[key] != self.package_info[key]:
                    return False
        else:
            return True

