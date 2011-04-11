#!/usr/bin/python
# -*- coding: utf-8 -*-
"""
      parabola.py      
      Copyright 2009  Rafik Mas'ad
      Copyright 2010 Joshua Ismael Haase Hernández

     ---------- GNU General Public License 3 ----------
                                                                             
     This file is part of Parabola.                                          
                                                                             
     Parabola is free software: you can redistribute it and/or modify        
     it under the terms of the GNU General Public License as published by    
     the Free Software Foundation, either version 3 of the License, or       
     (at your option) any later version.                                     
                                                                             
     Parabola is distributed in the hope that it will be useful,             
     but WITHOUT ANY WARRANTY; without even the implied warranty of          
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           
     GNU General Public License for more details.                            
                                                                             
     You should have received a copy of the GNU General Public License       
     along with Parabola.  If not, see <http://www.gnu.org/licenses/>.       
                                                                             

"""
from repm.config import *
from repm.filter import *
import tarfile
from os.path import isdir, isfile

def generate_rsync_command(base_command,
                           dir_list=(config["repo_list"] +
                                     config["dir_list"]),
                           destdir=config["repodir"],
                           source=config["mirror"] +config["mirrorpath"]):
    """ Generates an rsync command for executing
    it by combining all parameters.
    
    Parameters:
    ----------
    base_command   -> str
    dir_list       -> list or tuple
    destdir        -> str                  Path to dir, dir must exist.
    source         -> str                  The source for rsync
    blacklist_file -> False or str         Path to file, file must exist.
    
    Return:
    ----------
    rsync_command -> str """
    if not os.path.isdir(destdir):
        print(destdir + " is not a directory")
        raise NonValidDir

    dir_list="{" + ",".join(dir_list) + "}"
    return " ".join((base_command, os.path.join(source, dir_list),
                     destdir))

def run_rsync(command,debug=config["debug"]):
    """ Runs rsync and gets returns it's output """
    if debug:
        printf("rsync_command: " + command)
    return check_output(command.split())
