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

config_directory="${XDG_CONFIG_HOME:-"$HOME/.config"}/update"
repository_file="$config_directory/repositories"

if [ -L "$repository_file" ]; then
    repository_file="$(readlink "$repository_file")"
fi

repositories=()

while read -r line; do
    repositories+=("${line/\~/"$HOME"}")
done < "$repository_file"

for directory in "${repositories[@]}"; do
    [ ! -e "$directory" ] && continue

    if [ -L "$directory" ]; then
        directory="$(readlink "$directory")"
    fi
    if [[ "$directory" =~ ^.*\/$ ]]; then
        directory="${directory::-1}"
    fi
    
    [ ! -e "$directory" ] && continue

    echo -e "Updating repositories in '${directory/"$HOME"/\~}'\n"

    for project in "$directory"/*; do
        [ ! -e "$project" ] && continue
    
        if [ -L "$project" ]; then
            project="$(readlink "$project")"
        fi
        if [[ "$project" =~ ^.*\/$ ]]; then
            project="${project::-1}"
        fi
        
        [ ! -e "$project" ] && continue
        
        project_name="${project#"$directory/"}"

        if [ ! -e "$project/.git" ]; then
            echo "~ Skipping '$project_name' (Non-git)"

            continue
        fi

        (
            cd "$project" || exit $?
            
            if [ -z "$(git remote)" ]; then
                echo "~ Skipping '$project_name' (Local)"

                exit 0
            fi
            if [ -n "$(git status --porcelain)" ]; then
                echo "~ Skipping '$project_name' (Modified)"

                exit 0
            fi

            echo "- Updating '$project_name'"

            git pull > /dev/null || exit $?
        ) || exit $?
    done

    echo
done

echo "Successfully updated projects"
