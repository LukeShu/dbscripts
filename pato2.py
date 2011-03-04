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
from glob import glob
from os.path import isdir, isfile

def printf(text,output_=output):
    """Guarda el texto en la variable log y puede imprimir en pantalla."""
    log_file = open(logname, 'a')
    log_file.write("\n" + str(text) + "\n")
    log_file.close()
    if output_: print (str(text) + "\n")

def listado(filename_):
    """Obtiene una lista de paquetes de un archivo."""
    archivo = open(filename_,"r")
    lista   = archivo.read().split("\n")
    archivo.close()
    return [pkg.split(":")[0].rstrip() for pkg in lista if pkg]

def db(repo_,arch_):
    """Construye un nombre para sincronizar una base de datos."""
    return "/%s/os/%s/%s.db.tar.gz" % (repo_, arch_, repo_)

def packages(repo_, arch_, expr="*"):
    """ Get packages on a repo, arch folder """
    return tuple( glob( repodir + "/" + repo_ + "/os/" + arch_ + "/" + expr ) )

def sync_all_repo(debug=verbose):
    cmd=generate_rsync_command(rsync_list_command)
    rsout=run_rsync(cmd)
    pkgs=pkginfo_from_rsync_output(rsout)
    generate_exclude_list_from_blacklist(pkgs,listado(blacklist))
    cmd=generate_rsync_command(rsync_update_command,blacklist_file=blacklist)
    a=run_rsync(cmd)
    if debug: printf(a)

def get_from_desc(desc, var,db_tar_file=False):
    """ Get a var from desc file """
    desc = desc.split("\n")
    return desc[desc.index(var)+1]

def get_info(repo_,arch_,db_tar_file=False,verbose_=verbose):
    """ Makes a list of package name, file and license """
    info=list()
    # Extract DB tar.gz    
    commands.getoutput("mkdir -p " + archdb)
    if not db_tar_file:
        db_tar_file = repodir + db(repo_,arch_)
    if isfile(db_tar_file):
        try:
            db_open_tar = tarfile.open(db_tar_file, 'r:gz')
        except tarfile.ReadError:
            printf("No valid db_file %s" % db_tar_file)
            return(tuple())
    else:
        printf("No db_file %s" % db_tar_file)
        return(tuple())
    for file in db_open_tar.getmembers():
        db_open_tar.extract(file, archdb)
    db_open_tar.close()
    # Get info from file
    for dir_ in glob(archdb + "/*"):
        if isdir(dir_) and isfile(dir_ + "/desc"):
            pkg_desc_file = open(dir_ + "/desc", "r")
            desc = pkg_desc_file.read()
            pkg_desc_file.close()
            info.append((  get_from_desc(desc,"%NAME%"),
                       dir_.split("/")[-1],
                       get_from_desc(desc,"%LICENSE%")  ))
    if verbose_: printf(info)
    commands.getoutput("rm -r %s/*"  % archdb)
    return tuple(info)

def make_pending(repo_,arch_,info_):
    """ Si los paquetes no están en blacklist ni whitelist y la licencia contiene "custom" los agrega a pending"""
    search = tuple( listado(blacklist) + listado (whitelist) )
    if verbose: printf("blaclist + whitelist= " + str(search) )
    lista_=list()
    for (name,pkg_,license_) in info_:
        if "custom" in license_:
            if name not in search:
                lista_.append( (name, license_ ) )
        elif not name:
            printf( pkg_ + " package has no %NAME% attibute " )
    if verbose: printf( lista_ )
    a=open( pending + "-" + repo_ + ".txt", "w" ).write(
        "\n".join([name + ":" + license_ for (name,license_) in lista_]) )

def remove_from_blacklist(repo_,arch_,info_,blacklist_):
    """ Check the blacklist and remove packages on the db"""
    lista_=list()
    pack_=list()
    for (name_, pkg_, license_) in info_:
        if name_ in blacklist_:
            lista_.append(name_)
            for p in packages(repo_,arch_,pkg_ + "*"):
                pack_.append(p)
    if lista_:
        lista_=" ".join(lista_)
        com_ =  "repo-remove " + repodir + db(repo_,arch_) + " " + lista_ 
        printf(com_)
        a = commands.getoutput(com_) 
        if verbose: printf(a)

def link(repo_,arch_,file_):
    """ Makes a link in the repo for the package """
    cmd_="ln -f " + file_ + " " + repodir + "/" + repo_ + "/os/" + arch_
    a=commands.getoutput(cmd_)
    if verbose:
        printf(cmd_ + a)

def add_free_repo(verbose_=verbose):
    cmd_=home + "/usr/bin/sync-free"
    printf(cmd_)
    a=commands.getoutput(cmd_)
    if verbose_: printf(a)
    for repo_ in repo_list:
        for arch_ in arch_list:
            lista_=list()
            for file_ in glob(freedir + repo_ + "/os/" + arch_ + "/*.pkg.tar.*"):
                lista_.append(file_)
            for dir_ in other:
                for file_ in glob(freedir + repo_ + "/os/" + dir_ + "/*.pkg.tar.*"):
                    lista_.append(file_)

            printf(lista_)

            if lista_:
                lista_=" ".join(lista_)
                if verbose: printf(lista_)
                cmd_="repo-add " + repodir + db(repo_,arch_) + " " + lista_ 
                printf(cmd_)
                a=commands.getoutput(cmd_)
                if verbose: printf(a)

def get_licenses(verbose_=verbose):
    """ Extract the license from packages in repo_,arch_ and in pending_ file"""
    cmd_=home + "/usr/bin/get_license.sh"
    printf(cmd_)
    a=commands.getoutput(cmd_)
    if verbose_: printf(a)

def generate_rsync_command(base_command, dir_list=(repo_list + dir_list), destdir=repodir,
                           source=mirror+mirrorpath, blacklist_file=False):
    """ Generates an rsync command for executing it by combining all parameters.
    
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
    from os.path import isfile, isdir

    if blacklist_file and not isfile(blacklist_file):
        print(blacklist_file + " is not a file")
        raise NonValidFile

    if not os.path.isdir(destdir):
        print(destdir + " is not a directory")
        raise NonValidDir

    dir_list="{" + ",".join(dir_list) + "}"

    if blacklist_file:
        return " ".join((base_command, "--exclude-from="+blacklist_file,
                        os.path.join(source, dir_list), destdir))
    return " ".join((base_command, os.path.join(source, dir_list), destdir))

def run_rsync(command,debug=verbose):
    """ Runs rsync and gets returns it's output """
    if debug:
        printf("rsync_command: " + command)
    return commands.getoutput(command)

if __name__ == "__main__":
    from time import time
    start_time = time()
    def minute():
        return str(round((time() - start_time)/60, 1))
    
    printf(" Cleaning %s folder " % (tmp) )
    commands.getoutput("rm -r %s/*" % tmp)
    printf(" Syncing repo")
    sync_all_repo(True)

    printf(" Updating databases and pending files lists: minute %s \n" % minute() )
    for repo in repo_list:
        for arch in arch_list:
            printf( "\n" + repo + "-" + arch + "\n" )
            printf( "Get info: minute %s "  % minute()  )
            info=get_info(repo,arch)
            printf( "Make pending: minute %s"  % minute()  )
            make_pending(repo,arch,info)
            printf( "Update DB: minute %s"  % minute()  )
            remove_from_blacklist(
                repo, arch, info, tuple( listado(blacklist) + listado(pending + "-" + repo + ".txt") ) )

    printf("Adding Parabola Packages: minute %s\n" % minute() )
    add_free_repo(True)
    
    printf("Extracting licenses in pending: minute %s" % minute() )
    get_licenses()
    
    printf("\n\nDelay: %s minutes \n" % minute())
    
