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

class pkginfo_from_file_KnownValues(unittest.TestCase):
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

class pkginfo_from_file_BadInput(unittest.TestCase):
    bad=("community-testing/os/i686/community-testing.db",
         "community-testing/os/i686/community-testing.db.tar.gz",
         "community-testing/os/i686/community-testing.db.tar.gz.old",
         "community-testing/os/i686/community-testing.files",
         "community-testing/os/i686/community-testing.files.tar.gz",
         "community-testing/os/x86_64")

    def testBadInput(self):
        for i in self.bad:
            self.assertRaises(NonValidFile,pkginfo_from_filename,i)

class pkginfoFromRsyncOutput(unittest.TestCase):
    example_package_list=(Package(),Package(),Package())
    example_package_list[0].package_info={ "name"    : "alex",
                                           "version" : "2.3.4",
                                           "release" : "1",
                                           "arch"    : "i686",
                                           "license" : False,
                                           "location": "community-staging/os/i686/alex-2.3.4-1-i686.pkg.tar.xz",
                                           "depends" : False,}
    example_package_list[1].package_info={ "name"    : "any2dvd",
                                           "version" : "0.34",
                                           "release" : "4",
                                           "arch"    : "any",
                                           "license" : False,
                                           "location": "community/os/any/any2dvd-0.34-4-any.pkg.tar.xz",
                                           "depends" : False,}
    example_package_list[2].package_info={ "name"    : "gmime22",
                                           "version" : "2.2.26",
                                           "release" : "1",
                                           "arch"    : "x86_64",
                                           "license" : False,
                                           "location": "community/os/x86_64/gmime22-2.2.26-1-x86_64.pkg.tar.xz",
                                           "depends" : False,}

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
        self.assertEqual(self.pkglist,self.example_package_list)

class generateRsyncBlacklist(unittest.TestCase):
    example_package_list=(Package(),Package(),Package())
    example_package_list[0].package_info={ "name"    : "alex",
                                           "version" : "2.3.4",
                                           "release" : "1",
                                           "arch"    : "i686",
                                           "license" : False,
                                           "location": "community-staging/os/i686/alex-2.3.4-1-i686.pkg.tar.xz",
                                           "depends" : False,}
    example_package_list[1].package_info={ "name"    : "any2dvd",
                                           "version" : "0.34",
                                           "release" : "4",
                                           "arch"    : "any",
                                           "license" : False,
                                           "location": "community/os/any/any2dvd-0.34-4-any.pkg.tar.xz",
                                           "depends" : False,}
    example_package_list[2].package_info={ "name"    : "gmime22",
                                           "version" : "2.2.26",
                                           "release" : "1",
                                           "arch"    : "x86_64",
                                           "license" : False,
                                           "location": "community/os/x86_64/gmime22-2.2.26-1-x86_64.pkg.tar.xz",
                                           "depends" : False,}

    def testListado(self):
        self.assertEqual(listado("blacklist_sample"),["alex","gmime22"])

    def testExcludeFiles(self):
        a=rsyncBlacklist_from_blacklist(self.example_package_list, 
                                        listado("blacklist_sample"))
        b=[self.example_package_list[0]["location"],self.example_package_list[2]["location"]]
        self.assertEqual(a,b)

class pkginfo_from_descKnownValues(unittest.TestCase):
    pkgsample=Package()
    pkgsample.package_info={"name"    : "binutils",
                            "version" : "2.21",
                            "release" : "4",
                            "arch"    : "x86_64",
                            "license" : "GPL",
                            "location": "binutils-2.21-4-x86_64.pkg.tar.xz",
                            "depends" : False,}
    fsock=open("desc")
    pkggen=pkginfo_from_desc(fsock.read())
    fsock.close()
    def testPkginfoFromDesc(self):
        if self.pkggen is None:
            self.fail("return value is None")
        self.assertEqual(self.pkgsample,self.pkggen)
        
class pkginfo_from_db(unittest.TestCase):
    archdb = os.path.join("./workdir")
    example_package_list=(Package(),Package(),Package())
    example_package_list[0].package_info={ "name"    : "acl",
                                           "version" : "2.2.49",
                                           "release" : "2",
                                           "arch"    : "x86_64",
                                           "license" : ("LGPL",),
                                           "location": "acl-2.2.49-2-x86_64.pkg.tar.xz",
                                           "depends" : ("attr>=2.4.41"),}
    example_package_list[1].package_info={ "name"    : "glibc",
                                           "version" : "2.13",
                                           "release" : "4",
                                           "arch"    : "x86_64",
                                           "license" : ("GPL","LGPL"),
                                           "location": "glibc-2.13-4-x86_64.pkg.tar.xz",
                                           "depends" : ("linux-api-headers>=2.6.37","tzdata",),}
    example_package_list[2].package_info={ "name"    : "",
                                           "version" : "2.2.26",
                                           "release" : "1",
                                           "arch"    : "x86_64",
                                           "license" : False,
                                           "location": "",
                                           "depends" : False,}    
    
    
if __name__ == "__main__":
    unittest.main()

