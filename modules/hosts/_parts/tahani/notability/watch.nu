#!/usr/bin/env nu

use ./lib.nu *
use ./reconcile.nu [reconcile-run]
use ./worker.nu [worker-run]


def error-message [error: any] {
    let msg = (($error.msg? | default '') | into string)
    if $msg == '' {
        $error | to nuon
    } else {
        $msg
    }
}


def run-worker [] {
    try {
        worker-run --drain
    } catch {|error|
        print $"worker failed: (error-message $error)"
    }
}


def run-sync [] {
    run-worker

    try {
        reconcile-run
    } catch {|error|
        print $"reconcile failed: (error-message $error)"
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
