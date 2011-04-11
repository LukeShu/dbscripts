 #! /usr/bin/python
#-*- encoding: utf-8 -*-
from glob import glob
from repm.config import *
from repm.pato2 import *

def listado(filename):
    """Obtiene una lista de paquetes de un archivo."""
    archivo = open(filename,"r")
    lista   = archivo.read().split("\n")
    archivo.close()
    return [pkg.split(":")[0].rstrip() for pkg in lista if pkg]

def pkginfo_from_filename(filename):
    """ Generates a Package object with info from a filename,
    filename can be relative or absolute 
    
    Parameters:
    ----------
    filename -> str         Must contain .pkg.tar.

    Returns:
    ----------
    pkg -> Package object"""
    if ".pkg.tar." not in filename:
        raise NonValidFile
    pkg = Package()
    pkg["location"] = filename
    fileattrs = os.path.basename(filename).split("-")
    pkg["arch"] = fileattrs.pop(-1).split(".")[0]
    pkg["release"] = fileattrs.pop(-1)
    pkg["version"] = fileattrs.pop(-1)
    pkg["name"] = "-".join(fileattrs)
    return pkg

def pkginfo_from_desc(filename):
    """ Returns pkginfo from desc file.
    
    Parameters:
    ----------
    filename -> str          File must exist
    
    Returns:
    ----------
    pkg -> Package object"""
    if not os.path.isfile(filename):
        raise NonValidFile
    try:
        f=open(filename)
        info=f.read().rsplit()
    finally:
        f.close()
    pkg = Package()
    info_map={"name"    :("%NAME%"    , None),
              "version" :("%VERSION%" , 0    ),
              "release" :("%VERSION%" , 1    ),
              "arch"    :("%ARCH%"    , None),
              "license" :("%LICENSE%" , None),
              "location":("%FILENAME%", None),}

    for key in info_map.keys():
        field,pos=info_map[key]
        pkg[key]=info[info.index(field)+1]
        if pos is not None:
            pkg[key]=pkg[key].split("-")[pos]
    return pkg

def pkginfo_from_rsync_output(rsync_output):
    """ Generates a list of packages and versions from an rsync output
    wich uses --list-only and --no-motd options.

    Parameters:
    ----------
    rsync_output -> str          Contains output from rsync
    
    Returns:
    ----------
    package_list -> tuple        Contains Package objects. """

    def package_or_link(line):
        """ Take info out of filename """
        location_field = 4
        return pkginfo_from_filename(line.rsplit()[location_field])

    def do_nothing():
        pass

    options = { "d": do_nothing,
                "l": package_or_link,
                "-": package_or_link,
                " ": do_nothing}

    package_list=list()
    
    lines=[x for x in rsync_output.split("\n") if ".pkg.tar" in x]

    for line in lines:
        pkginfo=options[line[0]](line)
        if pkginfo:
            package_list.append(pkginfo)

    return tuple(package_list)

def pkginfo_from_files_in_dir(directory):
    """ Returns pkginfo from filenames of packages in dir
    wich has .pkg.tar. on them 
    
    Parameters:
    ----------
    directory -> str          Directory must exist
    
    Returns:
    ----------
    package_list -> tuple     Contains Package objects """
    package_list=list()

    if not os.path.isdir(directory):
        raise NonValidDir

    for filename in glob(os.path.join(directory,"*")):
        if ".pkg.tar." in filename:
            package_list.append(pkginfo_from_filename(filename))
    return tuple(package_list)

def pkginfo_from_db(path_to_db):
    """ Get PKGINFO from db.
    
    Parameters:
    ----------
    path_to_db -> str                 Path to file

    Output:
    ----------
    None """
    package_list=list()
    
    if not os.path.isfile(path_to_db):
        raise NonValidFile(path_to_db + "is not a file")
    
    check_output("mkdir -p " + archdb)

    try:
        db_open_tar = tarfile.open(db_tar_file, 'r:gz')
    except tarfile.ReadError:
        printf("No valid db_file %s or not readable" % db_tar_file)
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
            package_list.append(pkginfo_from_desc(
                    os.path.join(dir_,"desc")))
    check_output("rm -r %s/*"  % archdb)
    if verbose_:
        printf(package_list)
    return package_list

def generate_exclude_list_from_blacklist(packages_iterable,
                                         blacklisted_names,
                                         exclude_file=config["rsync_blacklist"],
                                         debug=config["debug"]):
    """ Generate an exclude list for rsync 
    
    Parameters:
    ----------
    package_iterable -> list or tuple       Contains Package objects
    blacklisted_names-> list or tuple       Contains blacklisted names
    exclude_file     -> str                 Path to file
    debug            -> bool                If True, file list gets logged

    Output:
    ----------
    None """
    pkgs=[pkg["location"] for pkg in packages_iterable
          if isinstance(pkg, Package)
          and pkg["name"] in blacklisted_names]

    if debug:
        return pkgs
    try:
        fsock = open(exclude_file,"w")
        try:
            fsock.write("\n".join(a))
        finally:
            fsock.close()
    except IOError:
        printf("%s wasnt written" % exclude_file)

if __name__ == "__main__":
    cmd=generate_rsync_command(rsync_list_command)
    a=run_rsync(cmd)
    packages=pkginfo_from_rsync_output(a)
    generate_exclude_list_from_blacklist(packages,listado(blacklist))
