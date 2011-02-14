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
    directory_list=("drwxrwxr-x          15 2010/09/11 11:28:50 community-staging",
                    "drwxrwxr-x          30 2010/09/11 11:28:50 community-staging/os",
                    'dr-xr-sr-x        4096 2010/09/11 11:37:10 .')
    # (rsync_out, name, version, arch, release, location)
    examples=(
        ("lrwxrwxrwx          53 2011/01/31 01:52:06 community-testing/os/i686/apvlv-0.1.0-2-i686.pkg.tar.xz -> ../../../pool/community/apvlv-0.1.0-2-i686.pkg.tar.xz", "apvlv","0.1.0","i686", "2", "community-testing/os/i686/apvlv-0.1.0-2-i686.pkg.tar.xz"),
        ("lrwxrwxrwx          56 2011/02/04 14:34:08 community-testing/os/i686/calibre-0.7.44-2-i686.pkg.tar.xz -> ../../../pool/community/calibre-0.7.44-2-i686.pkg.tar.xz","calibre","0.7.44","i686", "2", "community-testing/os/i686/calibre-0.7.44-2-i686.pkg.tar.xz"),
        ("-rw-rw-r--     5846249 2010/11/13 10:54:25 pool/community/abuse-0.7.1-1-x86_64.pkg.tar.gz",
         "abuse","0.7.1","x86_64","1","pool/community/abuse-0.7.1-1-x86_64.pkg.tar.gz"),
        ("-rw-rw-r--      982768 2011/02/05 14:38:17 pool/community/acetoneiso2-2.3-2-i686.pkg.tar.xz",
         "acetoneiso2","2.3","i686", "2", "pool/community/acetoneiso2-2.3-2-i686.pkg.tar.xz"),
        ("-rw-rw-r--      982764 2011/02/05 14:38:40 pool/community/acetoneiso2-2.3-2-x86_64.pkg.tar.xz",
         "acetoneiso2","2.3","x86_64","2","pool/community/acetoneiso2-2.3-2-x86_64.pkg.tar.xz")
        )

    def generate_results(self, example_tuple, attr):
        rsync_out, name, version, arch, release, location = example_tuple
        return pkginfo_from_rsync_output(rsync_out)[0][attr], locals()[attr]
    
    def testDirectoryOutput(self):
        """pkginfo_from_rsync_output should ignore directories"""
        rsync_out="\n".join(self.directory_list)
        result=pkginfo_from_rsync_output(rsync_out)
        self.assertEqual(tuple(), result)

    def testNames(self):
        for i in self.examples:
            k,v = self.generate_results(example_tuple=i,attr="name")
            self.assertEqual(k, v)

    def testVersions(self):
        for i in self.examples:
            k,v = self.generate_results(example_tuple=i,attr="version")
            self.assertEqual(k, v)

    def testArchs(self):
        for i in self.examples:
            k,v = self.generate_results(example_tuple=i,attr="arch")
            self.assertEqual(k, v)

    def testReleases(self):
        for i in self.examples:
            k,v = self.generate_results(example_tuple=i,attr="release")
            self.assertEqual(k, v)

    def testLocations(self):
        for i in self.examples:
            k,v = self.generate_results(example_tuple=i,attr="location")
            self.assertEqual(k, v)
      
if __name__ == "__main__":
    unittest.main()
