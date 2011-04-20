#!/bin/bash
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

source ./config
source ./local_config
source ./libremessages                                                   

msg "Creating pending licenses list"
pushd ${licenses_dir} >/dev/null
rm -rf ${licenses_dir}/*
popd >/dev/null

dir=$(mktemp -d ${tempdir}/licenses.XXXX)
pushd $dir > /dev/null

for repo in ${ARCHREPOS[@]}; do
    msg2 "Extracting licenses in ${repo}"
    pending=($(cut -d: -f1 ${docs_dir}/pending-${repo}.txt))
    for name in ${pending[@]}; do
	plain "${pkg}"
	for pkg in $(find ${repodir}/staging/${repo} -name "${name}-*${PKGEXT}" -printf '%f '); do
	    chmod +r ${pkg}
	    bsdtar -xf ${pkg} usr/share/licenses || {
		error "${pkg} has no licenses"
	    }
	    chmod -r ${pkg}
	done
    done
done

mv ${dir}/* ${licenses_dir}/
rm -rf ${dir}


exit 0
