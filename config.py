#!/usr/bin/python
# -*- coding: utf-8 -*-
try:
    from subprocess import check_output
except(ImportError):
    from commands import getoutput as check_output
import os

stringvars=("mirror", "mirrorpath", "logname", "tempdir", "docs_dir",
            "repodir", "rsync_blacklist")
listvars=("repo_list", "dir_list", "arch_list", "other",)
boolvars=("output", "debug",)

config=dict()

def exit_if_none(var):
    if os.environ.get(var) is None:
        exit("%s is not defined" % var)

for var in stringvars:
    exit_if_none(var)
    config[var]=os.environ.get(var)

for var in listvars:
    exit_if_none(var)
    config[var]=tuple(os.environ.get(var).split(":"))

for var in boolvars:
    exit_if_none(var)
    if os.environ.get(var) == "True":
        config[var]=True
    elif os.environ.get(var) =="False":
        config[var]=False
    else:
        print('%s is not True or False' % var)

# Rsync commands
rsync_list_command="rsync -a --no-motd --list-only "

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

if __name__=="__main__":
    for key in config.keys():
        print("%s : %s" % (key,config[key]))
