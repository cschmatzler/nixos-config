# Replaces fish's built-in OSC 7 reporter: Herdr must see the host's
# machine name, not the container hostname, for cwd-follow to work.
function __fish_update_cwd_osc --on-variable PWD --on-event fish_prompt \
    --description 'Notify terminals when $PWD might have changed'
    test "$TERM" = dumb; and return
    printf '\e]7;file://%s%s\a' (string escape --style=url -- "$HERDR_HOST_NAME" "$PWD")
end

__fish_update_cwd_osc
