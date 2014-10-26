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

If the --keyset argument is passed, print the key fingerprint of every
signed package.
"""


import base64
import subprocess
import sys
import tarfile


def main():
    """Do the job."""
    check_keys = False
    if "--keyset" in  sys.argv:
        sys.argv.remove("--keyset")
        check_keys = True
    repo = sys.argv[1]
    pkgarches = frozenset(name.encode("utf-8") for name in sys.argv[2:])
    packages = []
    keys = []
    with tarfile.open(fileobj=sys.stdin.buffer) as archive:
        for entry in archive:
            if entry.name.endswith("/desc"):
                content = archive.extractfile(entry)
                skip = False
                is_arch = False
                key = None
                for line in content:
                    if is_arch:
                        is_arch = False
                        if pkgarches and line.strip() not in pkgarches:
                            skip = True  # different architecture
                            break
                    if line == b"%PGPSIG%\n":
                        skip = True  # signed
                        key = b""
                        if check_keys:
                            continue
                        else:
                            break
                    if line == b"%ARCH%\n":
                        is_arch = True
                        continue
                    if key is not None:
                        if line.strip():
                            key += line.strip()
                        else:
                            break
                if check_keys and key:
                    key_binary = base64.b64decode(key)
                    keys.append(key_binary)
                    packages.append(repo + "/" + entry.name[:-5])
                if skip:
                    continue
                print(repo + "/" + entry.name[:-5])
    if check_keys and keys:
        # We have collected all signed package names in packages and
        # all keys in keys.  Let's now ask gpg to list all signatures
        # and find which keys made them.
        packets = subprocess.check_output(("gpg", "--list-packets"),
                                          input=b"".join(keys))
        i = 0
        for line in packets.decode("latin1").split("\n"):
            if line.startswith(":signature packet:"):
                keyid = line[line.index("keyid ") + len("keyid "):]
                print(packages[i], keyid)
                i += 1


if __name__ == "__main__":
    main()
