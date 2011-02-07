time__ = commands.getoutput("date +%Y%m%d-%H:%M")

# Mirror Parameters
mirror = "mirrors.eu.kernel.org"
mirrorpath = "::mirrors/archlinux"

# Directories and files
## Optionals
path   = home + "/parabolagnulinux.org"
docs   = path + "/docs"
logdir = path + "/log"
## Must be defined
logname= logdir + "/" + time__ + "-repo-maintainer.log"
repodir= path + "/repo"
tmp    = home + "/tmp"
archdb = tmp  + "/db"

# Repo, arch, and other folders to use for repo
repo_list = ("core", "extra", "community", "testing", "community-testing", "multilib")
dir_list  = ("pool","sources")
arch_list = ("i686", "x86_64")
other     = ("any",)

# Output
output    = True
verbose   = False

# Files
blacklist = docs + "/blacklist.txt"
whitelist = docs + "/whitelist.txt"
pending   = docs + "/pending"
rsyncBlacklist = docs + "/rsyncBlacklist"
