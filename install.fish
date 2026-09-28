#! /usr/bin/env fish

# Swaps out remote plugin for local for testing, and installs update-hyprsunset
# script and systemd service.

set plugin aidenlangley/sunriseset.fish

switch $argv
    case local
        fisher remove $plugin
        fisher install $PWD
    case remote
        fisher remove $PWD
        fisher install $plugin
    case script
        cp -v "$PWD/update-hyprsunset" "$HOME/.local/bin"
        chmod +x "$HOME/.local/bin/update-hyprsunset"
        printf "%s %s\n" (set_color -o green)OK(set_color --reset) "Installed $HOME/.local/bin/update-hyprsunset"
    case service
        cp -v "$PWD/update-hyprsunset.service" "$XDG_CONFIG_HOME/systemd/user"
        printf "%s %s\n" (set_color -o green)OK(set_color --reset) "Installed $XDG_CONFIG_HOME/systemd/user/update-hyprsunset.service"
        systemctl --user enable update-hyprsunset.service --now
    case '*'
        printf "%s %s\n" (set_color -o red)ERR(set_color --reset) 'Must pass either local, remote, script or service'
end
