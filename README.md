# Scripts

This is a collection of scripts for use in linux installations. This repository's intended target is Ubuntu 24.04.

## Usage

To use a script, simply run it from the command-line.

```sh
git clone https://github.com/Jaxydog/Scripts.git scripts
./scripts/src/install.sh # Runs the Ubuntu installation setup script.
```

## Updates

This repository contains an update script, `./src/update.sh`. By default, it updates the following installations:

- `apt` - Runs the equivalent of `sudo apt update -q && sudo apt upgrade -qy && sudo apt autoremove -qy`
- `snap` - Runs `sudo snap refresh`
- `rust` - Runs the equivalent of `rustup self update && rustup upgrade`
- `cargo` - Runs `cargo install-update -ag`, installing [`cargo-update`](https://crates.io/crates/cargo-update) if absent.

It also allows for easy extension though the script directory. Custom scripts may be placed within `~/.config/update/script/` and they will be run automatically.

This repository also includes some of my own custom scripts, located within the `update` directory.

The update script permits the following arguments when run:

```sh
-h              Displays this usage screen.
-v              Displays the current script version.
-l              Displays all ignored and/or pinned sections.

-i [section]    Ignores the provided section during this run.

-p [section]    Pins the provided section for future runs.
-u [section]    Un-pins the provided section for future runs.
```

## License

Scripts is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

Scripts is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Scripts, within LICENSE. If not, see <https://www.gnu.org/licenses/>.
