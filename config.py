#!/usr/bin/python
# -*- coding: utf-8 -*-
from user import home
import commands

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
repodir= path + "/repo"
tmp    = home + "/tmp"
archdb = tmp  + "/db"

free_path= path + "/free/"

# Repo, arch, and other folders to use for repo
repo_list = ("core", "extra", "community", "testing", "community-testing", "multilib")
dir_list  = ("pool","sources")
arch_list = ("i686", "x86_64")
other     = ("any",)

# Output
output    = True
verbose   = False

# Files
blacklist = docs + "/blacklist.txt"
whitelist = docs + "/whitelist.txt"
pending   = docs + "/pending"
rsyncBlacklist = docs + "/rsyncBlacklist"

# Classes and Exceptions
class NonValidFile(ValueError): pass
class NonValidDir(ValueError): pass
class NonValidCommand(ValueError): pass

class Package:
    """ An object that has information about a package. """
    package_info={ "name"    : False,
                   "version" : False,
                   "release" : False,
                   "arch"    : False,
                   "license" : False,
                   "location": False}
    
    def __setitem__(self, key, item):
        return self.package_info.__setitem__(key, item)

    def __getitem__(self, key):
        return self.package_info.__getitem__(key)
    
    def __unicode__(self):
        return str(self.package_info)


