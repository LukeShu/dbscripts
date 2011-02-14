#! /usr/bin/python
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
    # (filename, name, version, release, arch)
    # filename is location
    known=(
        ("community-testing/os/i686/inputattach-1.24-3-i686.pkg.tar.xz","inputattach","1.24","3","i686"),
        ("community-testing/os/i686/ngspice-22-1-i686.pkg.tar.xz","ngspice","22","1","i686"),
        ("community-testing/os/i686/tmux-1.4-2-i686.pkg.tar.xz","tmux","1.4","2","i686"),
        ("community-testing/os/i686/tor-0.2.1.29-2-i686.pkg.tar.xz","tor","0.2.1.29","2","i686"),
        ("../../../pool/community/tor-0.2.1.29-2-i686.pkg.tar.xz","tor","0.2.1.29","2","i686"),
        ("community-testing/os/x86_64/inputattach-1.24-3-x86_64.pkg.tar.xz","inputattach","1.24","3","x86_64"),
        ("../../../pool/community/inputattach-1.24-3-x86_64.pkg.tar.xz","inputattach","1.24","3","x86_64"),
        ("tor-0.2.1.29-2-x86_64.pkg.tar.xz","tor","0.2.1.29","2","x86_64"),
        )

    def generate_results(self, example_tuple, attr):
        location, name, version, release, arch = example_tuple
        return pkginfo_from_filename(location)[attr], locals()[attr]

    def testReturnPackageObject(self):
        for i in self.known:
            location, name, version, release, arch = i
            self.assertIsInstance(pkginfo_from_filename(location),Package)

    def testNames(self):
        for i in self.known:
            k,v = self.generate_results(example_tuple=i,attr="name")
            self.assertEqual(k, v)

    def testVersions(self):
        for i in self.known:
            k,v = self.generate_results(example_tuple=i,attr="version")
            self.assertEqual(k, v)

    def testArchs(self):
        for i in self.known:
            k,v = self.generate_results(example_tuple=i,attr="arch")
            self.assertEqual(k, v)

    def testReleases(self):
        for i in self.known:
            k,v = self.generate_results(example_tuple=i,attr="release")
            self.assertEqual(k, v)

    def testLocations(self):
        for i in self.known:
            k,v = self.generate_results(example_tuple=i,attr="location")
            self.assertEqual(k, v)

class BadInput(unittest.TestCase):
    bad=("community-testing/os/i686/community-testing.db",
         "community-testing/os/i686/community-testing.db.tar.gz",
         "community-testing/os/i686/community-testing.db.tar.gz.old",
         "community-testing/os/i686/community-testing.files",
         "community-testing/os/i686/community-testing.files.tar.gz",
         "community-testing/os/x86_64")

    def testBadInput(self):
        for i in self.bad:
            self.assertRaises(NonValidFile,pkginfo_from_filename,i)

if __name__ == "__main__":
    unittest.main()
