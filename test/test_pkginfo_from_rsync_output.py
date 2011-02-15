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

class KnownValues(unittest.TestCase):
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

    def testFirstPkg(self): 
        first_package_info=Package()
        first_package_info.package_info={ "name"    : "alex",
                                          "version" : "2.3.4",
                                          "release" : "1",
                                          "arch"    : "i686",
                                          "license" : False,
                                          "location": "community-staging/os/i686/alex-2.3.4-1-i686.pkg.tar.xz"}
        if self.pkglist:
            first_package=self.pkglist[0]
        else:
            self.fail(self.pkglist)
        self.assertEqual(first_package,first_package_info)
      
if __name__ == "__main__":
    unittest.main()
