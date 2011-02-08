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
                    "drwxrwxr-x          30 2010/09/11 11:28:50 community-staging/os")
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

    def generate_results(self, example_tuple):
        rsync_out="\n".join([a for a,b,c,d,e,f in example_tuple])
        return get_file_list_from_rsync_output(rsync_out)
    
    def testDirectoryOutput(self):
        """get_file_list_from_rsync_output should ignore directories"""
        rsync_out="\n".join(self.directory_list)
        result=get_file_list_from_rsync_output(rsync_out)
        self.assertEqual(tuple(), result)

    def testNames(self):
        results=self.generate_results(self.examples)
        var =[name for rsync_out, name, version, arch, release, location in self.examples]
        for i in range(len(results)):
            self.assertEqual(results[i]["name"], var[i])

    def testVersions(self):
        results=self.generate_results(self.examples)
        var = [version for rsync_out, name, version, arch, release, location in self.examples]
        for i in range(len(results)):
            self.assertEqual(results[i]["name"], var[i])

    def testArchs(self):
        results=self.generate_results(self.examples)
        var = [arch for rsync_out, name, version, arch, release, location in self.examples]
        for i in range(len(results)):
            self.assertEqual(results[i]["name"], var[i])

    def testReleases(self):
        results=self.generate_results(self.examples)
        var = [release for rsync_out, name, version, arch, release, location in self.examples]
        for i in range(len(results)):
            self.assertEqual(results[i]["name"], var[i])

    def testLocations(self):
        results=self.generate_results(self.examples)
        var = [location for rsync_out, name, version, arch, release, location in self.examples]
        for i in range(len(results)):
            self.assertEqual(results[i]["name"], var[i])
        
if __name__ == "__main__":
    unittest.main()
