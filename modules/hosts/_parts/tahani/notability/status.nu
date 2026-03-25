#!/usr/bin/env nu

use ./lib.nu *


def format-summary [] {
    let counts = (sql-json '
        select status, count(*) as count
        from notes
        group by status
        order by status;
    ')
    let queue = (sql-json "
        select status, count(*) as count
        from jobs
        where status in ('queued', 'running', 'failed')
        group by status
        order by status;
    ")

    let lines = [
        $"notes db: (db-path)"
        $"webdav root: (webdav-root)"
        $"notes root: (notes-root)"
        ''
        'notes:'
    ]

    let note_statuses = ('active,source_missing,source_deleted,conflict,failed' | split row ',')
    let note_lines = (
        $note_statuses
        | each {|status|
            let row = ($counts | where {|row| ($row | get 'status') == $status } | first)
            let count = ($row.count? | default 0)
            $"  ($status): ($count)"
        }
    )

    let job_statuses = ('queued,running,failed' | split row ',')
    let job_lines = (
        $job_statuses
        | each {|status|
            let row = ($queue | where {|row| ($row | get 'status') == $status } | first)
            let count = ($row.count? | default 0)
            $"  ($status): ($count)"
        }
    )

    ($lines ++ $note_lines ++ ['' 'jobs:'] ++ $job_lines ++ ['']) | str join "\n"
}


def format-note [note_id: string] {
    let note = (sql-json $"
        select *
        from notes
        where note_id = (sql-quote $note_id)
        limit 1;
    " | first)

    if $note == null {
        error make {
            msg: $"Unknown note id: ($note_id)"
        }
    }

    let jobs = (sql-json $"
        select job_id, operation, status, requested_at, started_at, finished_at, source_hash, error_summary
        from jobs
        where note_id = (sql-quote $note_id)
        order by requested_at desc
        limit 5;
    ")
    let events = (sql-json $"
        select ts, kind, details
        from events
        where note_id = (sql-quote $note_id)
        order by ts desc
        limit 10;
    ")
    let output_exists = ($note.output_path | path exists)
    let frontmatter = (parse-output-frontmatter $note.output_path)

    let lines = [
        $"note_id: ($note.note_id)"
        $"title: ($note.title)"
        $"status: ($note.status)"
        $"source_relpath: ($note.source_relpath)"
        $"output_path: ($note.output_path)"
        $"output_exists: ($output_exists)"
        $"managed_by: ($frontmatter.managed_by? | default '')"
        $"frontmatter_note_id: ($frontmatter.note_id? | default '')"
        $"current_source_hash: ($note.current_source_hash? | default '')"
        $"last_generated_output_hash: ($note.last_generated_output_hash? | default '')"
        $"current_archive_path: ($note.current_archive_path? | default '')"
        $"last_processed_at: ($note.last_processed_at? | default '')"
        $"missing_since: ($note.missing_since? | default '')"
        $"deleted_at: ($note.deleted_at? | default '')"
        $"conflict_path: ($note.conflict_path? | default '')"
        $"last_error: ($note.last_error? | default '')"
        ''
        'recent jobs:'
    ]

    let job_lines = if ($jobs | is-empty) {
        ['  (none)']
    } else {
        $jobs | each {|job|
            $"  ($job.job_id) [($job.status)] ($job.operation) requested=($job.requested_at) error=($job.error_summary? | default '')"
        }
    }

    let event_lines = if ($events | is-empty) {
        ['  (none)']
    } else {
        $events | each {|event|
            $"  ($event.ts) ($event.kind) ($event.details? | default '')"
        }
    }

    ($lines ++ $job_lines ++ ['' 'recent events:'] ++ $event_lines ++ ['']) | str join "\n"
}


def format-filtered [status: string, label: string] {
    let notes = (sql-json $"
        select note_id, title, source_relpath, output_path, status, last_error, conflict_path
        from notes
        where status = (sql-quote $status)
        order by last_seen_at desc;
    ")

    let header = [$label]
    let body = if ($notes | is-empty) {
        ['  (none)']
    } else {
        $notes | each {|note|
            let extra = if $status == 'conflict' {
                $" conflict_path=($note.conflict_path? | default '')"
            } else if $status == 'failed' {
                $" last_error=($note.last_error? | default '')"
            } else {
                ''
            }
            $"  ($note.note_id) ($note.title) [($note.status)] source=($note.source_relpath) output=($note.output_path)($extra)"
        }
    }

    ($header ++ $body ++ ['']) | str join "\n"
}


def format-queue [] {
    let jobs = (sql-json "
        select job_id, note_id, operation, status, requested_at, started_at, error_summary
        from jobs
        where status in ('queued', 'running', 'failed')
        order by requested_at asc;
    ")

    let lines = if ($jobs | is-empty) {
        ['queue' '  (empty)' '']
    } else {
        ['queue'] ++ ($jobs | each {|job|
            $"  ($job.job_id) note=($job.note_id) [($job.status)] ($job.operation) requested=($job.requested_at) error=($job.error_summary? | default '')"
        }) ++ ['']
    }

    $lines | str join "\n"
}


def main [note_id?: string, --failed, --queue, --deleted, --conflicts] {
    ensure-layout

    if $queue {
        print (format-queue)
        return
    }

    if $failed {
        print (format-filtered 'failed' 'failed notes')
        return
    }

    if $deleted {
        print (format-filtered 'source_deleted' 'deleted notes')
        return
    }

    if $conflicts {
        print (format-filtered 'conflict' 'conflict notes')
        return
    }

    if $note_id != null {
        print (format-note $note_id)
        return
    }

    print (format-summary)
}
