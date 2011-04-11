#!/bin/sh
# -*- coding: utf-8 -*-

     #  get_license.sh
     #  Copyright 2010 Joshua Ismael Haase Hernández

     # ---------- GNU General Public License 3 ----------
                                                                             
     # This file is part of Parabola.                                          
                                                                             
     # Parabola is free software: you can redistribute it and/or modify        
     # it under the terms of the GNU General Public License as published by    
     # the Free Software Foundation, either version 3 of the License, or       
     # (at your option) any later version.                                     
                                                                             
     # Parabola is distributed in the hope that it will be useful,             
     # but WITHOUT ANY WARRANTY; without even the implied warranty of          
     # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           
     # GNU General Public License for more details.                            
                                                                             
     # You should have received a copy of the GNU General Public License       
     # along with Parabola.  If not, see <http://www.gnu.org/licenses/>.       
                                                                             
docs="/home/parabolavnx/parabolagnulinux.org/docs"
repo="/home/parabolavnx/parabolagnulinux.org/repo"
dir="$docs/pending-licenses"

echo "Cleaning $dir"
rm -rf $dir/*

tempdir=$(mktemp -d)
cd $tempdir

pending=($(cut -d: -f1 $docs/pending*.txt))
echo ${pending[@]}

for pkg in ${pending[@]}; do
    pkg_in_repo=( $(ls ${repo}/*/os/*/${pkg}*) )
    for y in ${pkg_in_repo[@]}; do
	echo "chmod +r $y"
	chmod +r $y
	echo "tar -xf $y usr/share/licenses"
	bsdtar -xf $y usr/share/licenses
	echo "chmod -r $y"
	chmod -r $y
    done
done

mv usr/share/licenses/* $dir

cd

rm -rf $tempdir

exit 0