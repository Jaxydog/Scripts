#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright © 2024 Jaxydog
#
# This file is part of Scripts.
#
# Scripts is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#
# Scripts is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with Scripts. If not, see <https://www.gnu.org/licenses/>.

install_dir="${XDG_DATA_HOME:-"$HOME/.local/share"}/mold-git"
force_install=false

set -euo pipefail

if [ -L "$install_dir" ]; then
    install_dir="$(readlink "$install_dir")"

    if [ ! -e "$install_dir" ]; then
        echo "Broken symlink (missing dir '$install_dir')"

        exit 1
    fi
elif [ ! -d "$install_dir" ]; then
    mkdir -p "$install_dir"

    echo 'Downloading mold source'

    git clone --depth 1 --branch stable https://github.com/rui314/mold.git "$install_dir"

    force_install=true
fi

if [ ! -d "$install_dir/.git" ]; then
    echo "Source directory is not a git repository ('$install_dir')"

    exit 1
fi

(
    cd "$install_dir"

    if [ -z "$(git remote)" ]; then
        echo "Source directory does not have a remote URL ('$install_dir')"

        exit 1
    fi
    if [ -n "$(git status --porcelain)" ]; then
        echo "Source directory has been modified ('$install_dir')"

        exit 1
    fi

    echo "Checking for mold updates"

    git remote update

    current_commit="$(git log --oneline -n 1 HEAD)"
    remote_commit="$(git log --oneline -n 1 FETCH_HEAD)"

    if [ $force_install = false ] && [ -n "$(which mold)" ] && [ "$current_commit" = "$remote_commit" ]; then
        echo 'No updates found'

        exit 0
    fi

    echo 'Updates found, updating source'

    git pull
    git gc

    echo 'Checking prerequisite build dependencies'

    sudo ./install-build-deps.sh

    echo 'Compiling mold binary'

    [ -d ./build ] && rm -rf ./build

    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=c++ -B build
    cmake --build build -j$(nproc)
    sudo cmake --build build --target install

    echo 'Removing build artifacts'

    sudo rm -rf ./build

    echo 'Successfully updated mold'
)
