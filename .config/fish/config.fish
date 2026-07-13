source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
function fish_greeting
#    # smth smth
end

alias ff2='fastfetch --config ~/.config/fastfetch/smallfetch.jsonc'

function dl
       ~/scripts/madl.sh $argv
   end

set -gx QT_QPA_PLATFORMTHEME qt6ct

set -l ssh_env_file $HOME/.ssh/fish-ssh-agent-env

if not set -q SSH_AUTH_SOCK
    if test -f $ssh_env_file
        source $ssh_env_file > /dev/null
    end
end

if not set -q SSH_AUTH_SOCK; or not kill -0 $SSH_AGENT_PID > /dev/null 2>&1
    ssh-agent -c > $ssh_env_file
    source $ssh_env_file > /dev/null
    ssh-add ~/.ssh/id_ed25519 > /dev/null 2>&1
end
