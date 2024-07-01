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

# --------------------------------------------------------------------------- #

script_name='Update'
script_version='0.1.0'

config_directory="${XDG_CONFIG_HOME:-"$HOME/.config"}/update"
pinned_directory="$config_directory/pinned"
script_directory="$config_directory/script"

ignored_sections=()
pinned_sections=()

# --------------------------------------------------------------------------- #

declare -A colors

function define_color() {
	colors["$1"]="\e[${2}m"
}

define_color reset 0
define_color bold 1
define_color italics 3
define_color black 30
define_color white 97
define_color red 41
define_color green 42
define_color blue 46

unset define_color

function message() {
	local bg="$1"
	local fg="$2"

	shift 2

	echo -e "${colors[$bg]}${colors[$fg]} $* ${colors[reset]}\n"
}

function display() {
	message 'blue' 'black' "$*"
}

function success() {
	message 'green' 'black' "$*"
}

function failure() {
	message 'red' 'black' "$*"
}

# --------------------------------------------------------------------------- #

function print_version() {
    echo "$script_name v$script_version"
}

function print_argument() {
    local flag_pretty="${colors[bold]}$1${colors[reset]}"
    local desc_pretty="${colors[italics]}$2${colors[reset]}"
    local args_pretty

    if [ -n "$3" ]; then
        args_pretty=" [$3]\t"
    else
        args_pretty='\t\t'
    fi

    echo -e "$flag_pretty$args_pretty$desc_pretty"
}

function print_help() {
    echo -e "${colors[bold]}$script_name v$script_version${colors[reset]}"
    echo -e "usage: $0 [arguments]\n"

    print_argument '-h' 'Displays this usage screen.'
    print_argument '-v' 'Displays the current script version.'
    print_argument '-l' 'Displays all ignored and/or pinned sections.'
    echo
    print_argument '-i' 'Ignores the provided section during this run.' 'section'
    echo
    print_argument '-p' 'Pins the provided section for future runs.' 'section'
    print_argument '-u' 'Un-pins the provided section for future runs.' 'section'
}

function print_skipped() {
    display 'Skipped sections'

    local pinned_header="${colors[bold]}Pinned:${colors[reset]}"
    local ignored_header="${colors[bold]}Ignored:${colors[reset]}"
    local none="${colors[italics]}None.${colors[reset]}"

    if [ ${#pinned_sections[@]} -eq 0 ]; then
        echo -e "$pinned_header $none"
    else
        pinned=$(printf "%s" "${pinned_sections[@]}" | sed -r 's/ /, /g')

        echo -e "$pinned_header $pinned"
    fi

    if [ ${#ignored_sections[@]} -eq 0 ]; then
        echo -e "$ignored_header $none"
    else
        pinned=$(printf "%s" "${ignored_sections[@]}" | sed -r 's/ /, /g')

        echo -e "$ignored_header $pinned"
    fi
}

function abort() {
    declare -i exit_code=0

    if [[ "$1" =~ ^-?[0-9]+$ ]]; then
        exit_code="$1"
        shift 1
    fi

    failure "$*"

    exit $exit_code
}

function then_abort() {
    abort $? "$*"
}

function ignore_section() {
    local section="$1"

    [ -z "$section" ] && abort 1 'Expected a section title'
    
    ignored_sections+=("$section")
}

function pin_section() {
    local section="$1"

    [ -z "$section" ] && abort 1 'Expected a section title'

    mkdir -p "$pinned_directory" || then_abort 'Failed to create directory'

    for pinned in "${pinned_sections[@]}"; do
        [ "$pinned" -ne "$section" ] && continue

        display "Section '$section' is already pinned"

        return 0
    done

    touch "$pinned_directory/$section" || then_abort 'Failed to pin section'

    success "Pinned section '$section'"
}

function unpin_section() {
    local section="$1"

    [ -z "$section" ] && abort 1 'Expected a section title'

    for pinned in "${pinned_sections[@]}"; do
        [ "$pinned" -ne "$section" ] && continue

        rm "$pinned_directory/$section" || then_abort 'Failed to unpin section'

        success "Unpinned section '$section'"

        return 0
    done

    failure "Section '$section' is not pinned"

    return 1
}

function is_pinned() {
    local section="$1"

    [ -z "$section" ] && abort 1 'Expected a section title'

    for pinned in "${pinned_sections[@]}"; do
        [ "$pinned" -ne "$section" ] && continue

        return 0
    done
    
    return 1
}

function is_ignored() {
    local section="$1"

    [ -z "$section" ] && abort 1 'Expected a section title'

    for ignored in "${ignored_sections[@]}"; do
        [ "$ignored" -ne "$section" ] && continue

        return 0
    done

    return 1
}

function update_section() {
    local section="$1"

    [ -z "$section" ] && abort 1 'Expected a section title'
    
    if is_pinned "$section"; then
        display "Section '$section' is currently pinned"

        echo -e "To unpin this section, run '$0 -u $section'."

        return 0
    fi

    if is_ignored "$section"; then
        display "Section '$section' is being ignored"

        return 0
    fi

    shift 1

    display "Updating section '$section'"

    for command in "$@"; do
        [ -z "$command" ] && continue

        echo -e "> ${colors[italics]}$command${colors[reset]}\n"

        eval "$command" || then_abort "Failed to update section '$section'"

        echo
    done

    success "Successfully update section '$section'"
}

# --------------------------------------------------------------------------- #

if [ -d "$pinned_directory" ]; then
    for filename in "$pinned_directory"/*; do
        [ ! -e "$filename" ] && continue

        pinned_sections+=("${filename##*/}")
    done
fi

while getopts 'hvli:p:u:' argument; do
    case $argument in
        h) print_help; exit 0;;
        v) print_version; exit 0;;
        l) print_skipped; exit 0;;

        i) ignore_section "$OPTARG";;

        p) pin_section "$OPTARG"; exit $?;;
        u) unpin_section "$OPTARG"; exit $?;;

        *) print_help; exit 1;;
    esac
done

if [ -n "$(which apt)" ]; then
    update_section 'apt' 'sudo apt update -q' 'sudo apt upgrade -qy' 'sudo apt autoremove -qy'
fi

if [ -n "$(which snap)" ]; then
    update_section 'snap' 'sudo snap refresh'
fi

if [ -n "$(which rustup)" ]; then
    update_section 'rust' 'rustup self update' 'rustup upgrade'
fi

if [ -n "$(which cargo)" ]; then
    if cargo --list | grep -q 'install-update'; then
        update_section 'cargo' 'cargo install-update -ag'
    else
        update_section 'cargo' 'cargo install cargo-update' 'cargo install-update -ag'
    fi
fi

if [ -n "$(which tldr)" ]; then
    update_section 'tldr' 'tldr --update'
fi

if [ -d "$script_directory" ]; then
    for filename in "$script_directory"/*; do
        [ ! -e "$filename" ] && continue

        section="$(basename "$filename" '.sh')"

        update_section "$section" "$filename"

        unset section
    done
fi
