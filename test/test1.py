""" """

__author__ = "Joshua Ismael Haase Hernández <hahj87@gmail.com>"
__version__ = "$Revision: 1.1 $"
__date__ = "$Date: 2011/02/08 $"
__copyright__ = "Copyright (c) 2011 Joshua Ismael Haase Hernández"
__license__ = "GPL3+"

import repm.filter
import unittest
import commands

class KnownValues(unittest.TestCase):
    
    def testDirectoryOutput(self):
        """get_file_list_from_rsync_output should ignore directories"""
        output=commands.getoutput("cat ./directory_list")
        result=get_file_list_from_rsync_output(output)
        self.assertEqual(tuple(), result)

if __name__ == "__main__":
    unittest.main()
