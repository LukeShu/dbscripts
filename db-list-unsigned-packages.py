#!/usr/bin/env python3
# Copyright (C) 2012  Michał Masłowski  <mtjm@mtjm.eu>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


"""
Output a list of repo/package-name-and-version pairs representing
unsigned packages in the database at standard input of repo named in
the first argument and specified for architectures listed in the
following arguments (usually the one of the database or any, default
is to list all).
"""


import sys
import tarfile


def main():
    """Do the job."""
    repo = sys.argv[1]
    pkgarches = frozenset(name.encode("utf-8") for name in sys.argv[2:])
    with tarfile.open(fileobj=sys.stdin.buffer) as archive:
        for entry in archive:
            if entry.name.endswith("/desc"):
                content = archive.extractfile(entry)
                skip = False
                is_arch = False
                for line in content:
                    if is_arch:
                        is_arch = False
                        if pkgarches and line.strip() not in pkgarches:
                            skip = True  # different architecture
                            break
                    if line == b"%PGPSIG%\n":
                        skip = True  # signed
                        break
                    if line == b"%ARCH%\n":
                        is_arch = True
                if skip:
                    continue
                print(repo + "/" + entry.name[:-5])


if __name__ == "__main__":
    main()
