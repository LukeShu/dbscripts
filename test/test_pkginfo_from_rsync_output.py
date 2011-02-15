# -*- encoding: utf-8 -*-
""" """

__author__ = "Joshua Ismael Haase Hernández <hahj87@gmail.com>"
__version__ = "$Revision: 1.1 $"
__date__ = "$Date: 2011/02/08 $"
__copyright__ = "Copyright (c) 2011 Joshua Ismael Haase Hernández"
__license__ = "GPL3+"

from repm.config import *
from repm.filter import *
import unittest

example_package_list=(Package(),Package(),Package())
example_package_list[0].package_info={ "name"    : "alex",
                                        "version" : "2.3.4",
                                        "release" : "1",
                                        "arch"    : "i686",
                                        "license" : False,
                                        "location": "community-staging/os/i686/alex-2.3.4-1-i686.pkg.tar.xz"}
example_package_list[1].package_info={ "name"    : "any2dvd",
                                        "version" : "0.34",
                                        "release" : "4",
                                        "arch"    : "any",
                                        "license" : False,
                                        "location": "community/os/any/any2dvd-0.34-4-any.pkg.tar.xz"}
example_package_list[2].package_info={ "name"    : "gmime22",
                                        "version" : "2.2.26",
                                        "release" : "1",
                                        "arch"    : "x86_64",
                                        "license" : False,
                                        "location": "community/os/x86_64/gmime22-2.2.26-1-x86_64.pkg.tar.xz"}

class pkginfoFromRsyncOutput(unittest.TestCase):
    try:
        output_file = open("rsync_output_sample")
        rsync_out= output_file.read()
        output_file.close()
    except IOError: print("There is no rsync_output_sample file")

    pkglist = pkginfo_from_rsync_output(rsync_out)

    def testOutputArePackages(self):
        if not self.pkglist:
            self.fail("not pkglist:" + str(self.pkglist))
        for pkg in self.pkglist:
            self.assertIsInstance(pkg,Package)

    def testPackageInfo(self): 
        if not self.pkglist:
            self.fail("Pkglist doesn't exist: " + str(self.pkglist))
        self.assertEqual(self.pkglist,example_package_list)

class generateRsyncBlacklist(unittest.TestCase):
    """ Test Blacklist generation """
    def testListado(self):
        self.assertEqual(listado("blacklist_sample"),["alex","gmime22"])

    def testExcludeFiles(self):
        a=generate_exclude_list_from_blacklist(example_package_list,listado("blacklist_sample"),debug=True)
        b=[example_package_list[0]["location"],example_package_list[2]["location"]]
        self.assertEqual(a,b)

if __name__ == "__main__":
    unittest.main()
