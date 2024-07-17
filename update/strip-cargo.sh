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

cargo_bin_path="${CARGO_HOME:-"$HOME/.cargo"}/bin"
total_size=0;
total_stripped_size=0;

[ -d "$cargo_bin_path" ] || exit 0

pretty_bin_path="${cargo_bin_path/"$HOME"/'~'}"

echo "Stripping binaries in '$pretty_bin_path'"

function pretty_size() {
    local size="${1:-0}"
    local format="${2:-'%.1f'}"

    numfmt --to=iec-i --suffix=B --format="$format" "$size" | sed -e "s/^'//" -e "s/'$//"
}
function pretty_percent() {
    local first="${1:-1}"
    local second="${2:-1}"

    printf "%.1f%%" "$(echo "scale=3; (($first / $second) * 100) - 100" | bc)"
}

echo

for path in "$cargo_bin_path"/*; do
    { [ -f "$path" ] && [ ! -h "$path" ]; } || continue

    file_name="${path##"$cargo_bin_path/"}"

    [[ "$file_name" =~ ^(cargo|clippy|rust) ]] && continue

    file_size="$(stat -c%s "$path")"
    total_size=$((total_size + file_size))

    strip "$path"

    stripped_file_size="$(stat -c%s "$path")"
    total_stripped_size=$((total_stripped_size + stripped_file_size))

    percentage=$(pretty_percent "$stripped_file_size" "$file_size")
    file_size=$(pretty_size "$file_size")
    stripped_file_size=$(pretty_size "$stripped_file_size")

    printf -- "\055 %s: %s -> %s (%s)\n" "$file_name" "$file_size" "$stripped_file_size" "$percentage"
done

echo

if [ $total_size -ne 0 ]; then
    percentage=$(pretty_percent "$total_stripped_size" "$total_size")
    total_size=$(pretty_size "$total_size")
    total_stripped_size=$(pretty_size "$total_stripped_size")

    printf "Overall: %s -> %s (%s)\n" "$total_size" "$total_stripped_size" "$percentage"
else
    echo "No binaries modified."
fi
