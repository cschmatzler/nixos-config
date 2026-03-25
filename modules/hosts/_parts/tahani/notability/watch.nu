#!/usr/bin/env nu

use ./lib.nu *

const script_dir = (path self | path dirname)


def run-worker [] {
    let worker_script = ([ $script_dir 'worker.nu' ] | path join)
    let worker_result = (^nu $worker_script --drain | complete)
    if $worker_result.exit_code != 0 {
        print $"worker failed: ($worker_result.stderr | str trim)"
    }
}


def run-sync [] {
    let reconcile_script = ([ $script_dir 'reconcile.nu' ] | path join)

    run-worker

    let reconcile_result = (^nu $reconcile_script | complete)
    if $reconcile_result.exit_code != 0 {
        print $"reconcile failed: ($reconcile_result.stderr | str trim)"
        return
    }

    run-worker
}


def main [] {
    ensure-layout
    let root = (webdav-root)
    print $"Watching ($root) for Notability WebDAV updates"

    run-sync

    ^inotifywait -m -r --format '%w%f' -e create -e close_write -e moved_to -e moved_from -e delete -e attrib $root
    | lines
    | each {|changed_path|
        if not (is-supported-source-path $changed_path) {
            return
        }

        print $"Filesystem event for ($changed_path)"
        run-sync
    }
}
