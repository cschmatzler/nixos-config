if set -q HERDR_HOST_HOME; and test -n "$HERDR_HOST_HOME"
    for __herdr_var in (set --names)
        contains -- $__herdr_var PATH PWD; and continue
        string match -q -- 'HERDR_*' $__herdr_var; and continue
        string match -q -- 'fish_*' $__herdr_var; and continue
        string match -q -- '_*' $__herdr_var; and continue
        string match -q -- "*$HERDR_HOST_HOME*" $$__herdr_var; or continue
        set -gx $__herdr_var (string replace --all -- "$HERDR_HOST_HOME" "$HOME" $$__herdr_var)
    end
    set -e __herdr_var
end
