#!/usr/bin/python2
# -*- coding: utf-8 -*-
try:
    from subprocess import check_output
except(ImportError):
    from commands import getoutput
    def check_output(*popenargs,**kwargs):
        cmd=" ".join(*popenargs)
        return getoutput(cmd)
import os


# Rsync commands

def printf(text, logfile=False):
    """Guarda el texto en la variable log y puede imprimir en pantalla."""
    print (str(text) + "\n")
    if logfile:
        try:
            log = open(logfile, 'a')
            log.write("\n" + str(text) + "\n")
        except:
            print("Can't open %s" % logfile)
        finally:
            log.close()


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
