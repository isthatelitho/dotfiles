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

if not set -q SSH_AUTH_SOCK
    eval (ssh-agent -c)
end
