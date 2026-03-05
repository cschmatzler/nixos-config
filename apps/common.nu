#!/usr/bin/env nu

export def print_info [msg: string] {
    print $"(ansi blue)[INFO](ansi reset) ($msg)"
}

export def print_success [msg: string] {
    print $"(ansi green)[OK](ansi reset) ($msg)"
}

export def print_error [msg: string] {
    print $"(ansi red)[ERROR](ansi reset) ($msg)"
}

export def print_warning [msg: string] {
    print $"(ansi yellow)[WARN](ansi reset) ($msg)"
}
