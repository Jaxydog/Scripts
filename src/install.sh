#!/usr/bin/env bash

# --------------------------------------------------------------------------- #

declare -A colors

function define_color() {
	local name="$1"
	local code="$2"
	
	colors[$name]="\e[${code}m"
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

	echo -e "\n${colors[$bg]}${colors[$fg]} $* ${colors[reset]}\n"
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

function abort_process() {
	local exit_code=$?

	failure "$*"

	exit $exit_code
}

function update_apt() {
	display 'Updating apt packages'

	sudo apt update -q \
		|| abort_process 'Failed to update package listings'
	
	sudo apt upgrade -qy \
		|| abort_process 'Failed to upgrade packages'
	
	sudo apt autoremove -qy \
		|| abort_process 'Failed to remove packages'

	success 'Successfully updated apt packages'
}

function prompt() {
	local text="$1"
	local default="$2"

	if [ -z "$default" ]; then
		read -rp "$text: " response
	else
		read -rp "$text (default: $default): " response
	fi

	echo "${response:="$default"}"

	unset response
}

function required_prompt() {
	local value=""

	while [ -z "$value" ]; do
		value="$(prompt "$1" "$2")"
	done

	echo "$value"
}

# --------------------------------------------------------------------------- #

display 'Setting up Bash environment'

bashrc="$HOME/.bashrc"
bash_config_dir="$HOME/.config/bash"
bash_aliases="$bash_config_dir/.aliases"
bash_variables="$bash_config_dir/.variables"

if [ ! -d "$bash_config_dir" ]; then
	mkdir -p "$bash_config_dir" \
		|| abort_process 'Failed to create config directory'
fi

touch "$bash_aliases" "$bash_variables" \
	|| abort_process 'Failed to create config files'

if ! grep -q "$bash_aliases" "$bashrc"; then
	(echo "[ -f \"$bash_aliases\" ] && . '$bash_aliases'" >> "$bashrc") \
		|| abort_process 'Failed to add aliases to bashrc'
fi

if ! grep -q "$bash_variables" "$bashrc"; then
	(echo "[ -f \"$bash_variables\" ] && . '$bash_variables'" >> "$bashrc") \
		|| abort_process 'Failed to add variables to bashrc'
fi

success 'Successfully set up Bash environment'

# --------------------------------------------------------------------------- #

update_apt

display 'Installing APT packages'

apt_packages='bat cowsay gcc gh libssl-dev lolcat lua5.4 pkg-config sl'

sudo apt install $apt_packages -qy \
	|| abort_process 'Failed to install APT packages'

success 'Successfully install APT packages'

# --------------------------------------------------------------------------- #

if [ -z "$(which rustup)" ]; then
	display 'Installing Rust'

	(curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh) \
		|| abort_process 'Failed to install Rust'

	. "$HOME/.cargo/env"

	rustup toolchain install nightly \
		|| abort_process 'Failed to install Nightly toolchain'

	success 'Successfully installed Rust'
fi

display 'Installing Cargo binaries'

function install_binary() {
	local package="$1"

	shift 1

	cargo install "$package" \
		|| abort_process "Failed to install $package"

	for binary in "$@"; do
		strip "$(which "$binary")"
	done
}

install_binary 'eza' 'eza'
install_binary 'ripgrep' 'rg'
install_binary 'cargo-cache' 'cargo-cache'
install_binary 'cargo-update' 'cargo-install-update' 'cargo-install-update-config'

unset install_binary

success 'Successfully installed Cargo binaries'

# --------------------------------------------------------------------------- #

display 'Configuring batcat'

batcat_config_dir="$(batcat --config-dir)"
batcat_config_file="$(batcat --config-file)"
batcat_themes_dir="$batcat_config_dir/themes"
batcat_themes_url="https://github.com/catppuccin/bat/raw/main/themes"

if [ ! -d "$batcat_themes_dir" ]; then
	mkdir -p "$batcat_themes_dir" \
		|| abort_process 'Failed to create theme directory'
fi

touch "$batcat_config_file" \
	|| abort_process 'Failed to create config file'

function download_theme() {
	local name="$1.tmTheme"
	local link="$batcat_themes_url/$name"
	local file="$(echo "$batcat_themes_dir/$name" | sed -r 's/%20/ /g')"

	if [ ! -f "$file" ]; then
		wget -P "$batcat_themes_dir" "$link" \
			|| abort_process "Failed to download '$name'"
	else
		echo "Skipping '$name' as it is already installed"
	fi
}

download_theme 'Catppuccin%20Latte'
download_theme 'Catppuccin%20Frappe'
download_theme 'Catppuccin%20Macchiato'
download_theme 'Catppuccin%20Mocha'

unset download_theme

batcat cache --build

if ! grep -q 'theme=' "$batcat_config_file"; then
	(echo -e '--theme="Catppuccin Mocha"' >> "$batcat_config_file") \
		|| abort_process 'Failed to set default theme'
fi

if ! grep -q 'MANPAGER' "$bash_variables"; then
	(echo -e "export MANPAGER=\"sh -c 'col -bx | batcat -l man -p'\"" >> "$bash_variables") \
		|| abort_process 'Failed to update manpage theme'
fi

if ! grep -q 'MANROFFOPT' "$bash_variables"; then
	(echo -e "export MANROFFOPT='-c'" >> "$bash_variables") \
		|| abort_process 'Failed to update manpage theme'
fi

success 'Successfully configured batcat'

# --------------------------------------------------------------------------- #

display 'Configuring global Git settings'

function configure() {
	local key="$1"
	local value="$2"
	local command="git config --global '$key' '$value'"

	if [ -z "$(git config --global "$key")" ]; then
		echo "> $command"

		eval "$command" || abort_process "Failed to configure '$key'"
	else
		echo "Skipping '$key', as it is already configured"
	fi
}

configure 'branch.sort' 'committerdate'
configure 'column.ui' 'auto'
configure 'init.defaultBranch' 'main'

if [ -z "$(git config --global 'user.name')" ]; then
	git_user_name=$(prompt 'Enter Git username')
	[ -z "$git_user_name" ] && configure 'user.name' "$git_user_name"
else
	git_user_name="$(git config --global 'user.name')"
	echo "Skipping 'user.name', as it is already configured"
fi

if [ -z "$(git config --global 'user.email')" ]; then
	git_user_email=$(prompt 'Enter Git email')
	[ -z "$git_user_email" ] && configure 'user.email' "$git_user_email"
else
	git_user_email="$(git config --global 'user.email')"
	echo "Skipping 'user.email', as it is already configured"
fi

success 'Successfully configured global Git settings'

# --------------------------------------------------------------------------- #

if [ -z "$(git config --global 'user.signingkey')" ]; then
	display 'Configuring Git commit signing'

	while true; do
		gpg_user_name="$(required_prompt 'Enter GPG user name' "$USER")"
		gpg_timeout="$(required_prompt 'Enter GPG key timeout' "1y")"
		gpg_comment="$(prompt 'Enter comment (optional)')"

		if [ -z "$gpg_comment" ]; then
			gpg_user_id="$gpg_user_name <$git_user_email>"
		else
			gpg_user_id="$gpg_user_name ($gpg_comment) <$git_user_email>"
		fi

		echo -e "\nGPG user ID: $gpg_user_id"
		read -rp 'Is this correct? (Y/n) ' response

		([ "$response" = "y" ] || [ "$response" = "Y" ]) && break

		unset response
	done

	gpg --quick-generate-key "$gpg_user_name" rsa4096 sign "$gpg_timeout"

	gpg_key_id=$(\
		gpg --with-colons --keyid-format=long --list-secret-keys "=$gpg_user_name" \
		| grep --only-matching --perl-regexp 'sec:([^:]*:){3}\K[^:]+(?=:)'
	)
	gpg_key_file="$(mktemp -t "gpg_public_key.XXXX.pub")"
	gpg_key="$(gpg --armor --export "$gpg_key_id" | tee "$gpg_key_file")"

	configure 'commit.gpgsign' 'true'
	configure 'gpg.program' 'gpg'
	configure 'user.signingkey' "$gpg_key_id"

	unset configure

	if ! grep -q 'GPG_TTY' "$bash_variables"; then
		(echo -e "export GPG_TTY=\"\$(tty)\"" >> "$bash_variables") \
			|| abort_process 'Failed to update GPG TTY'
	fi

	echo 'This is the public key required by GitHub'
	echo -e "It is also available within '$gpg_key_file'.\n\n$gpg_key"

	success 'Successfully configured Git commit signing'
fi

# --------------------------------------------------------------------------- #

