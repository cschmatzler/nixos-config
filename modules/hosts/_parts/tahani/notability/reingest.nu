#!/usr/bin/env nu

use ./lib.nu *
use ./jobs.nu [archive-and-version, enqueue-job]
use ./worker.nu [worker-run]


def latest-version [note_id: string] {
    sql-json $"
        select *
        from versions
        where note_id = (sql-quote $note_id)
        order by seen_at desc
        limit 1;
    "
    | first
}


def existing-active-job [note_id: string, source_hash: string] {
    sql-json $"
        select job_id
        from jobs
        where note_id = (sql-quote $note_id)
          and source_hash = (sql-quote $source_hash)
          and status != 'done'
          and status != 'failed'
        order by requested_at desc
        limit 1;
    "
    | first
}


def archive-current-source [note: record] {
    if not ($note.source_path | path exists) {
        error make {
            msg: $"Current source path is missing: ($note.source_path)"
        }
    }

	let source_hash = (sha256 $note.source_path)
	let source_size = (((ls -l $note.source_path | first).size) | into int)
	let source_mtime = (((ls -l $note.source_path | first).modified) | format date "%Y-%m-%dT%H:%M:%SZ")
    let version = (archive-and-version $note.note_id $note.source_path $note.source_relpath $source_size $source_mtime $source_hash)

    sql-run $"
        update notes
        set current_source_hash = (sql-quote $source_hash),
            current_source_size = ($source_size),
            current_source_mtime = (sql-quote $source_mtime),
            current_archive_path = (sql-quote $version.archive_path),
            latest_version_id = (sql-quote $version.version_id),
            last_seen_at = (sql-quote (now-iso)),
            status = 'active',
            missing_since = null,
            deleted_at = null
        where note_id = (sql-quote $note.note_id);
    "
    | ignore

    {
        input_path: $version.archive_path
        archive_path: $version.archive_path
        source_hash: $source_hash
    }
}


def enqueue-reingest-job [note: record, source_hash: string, input_path: string, archive_path: string, force_overwrite_generated: bool] {
    let job = (enqueue-job $note 'reingest' $input_path $archive_path $source_hash $note.title $force_overwrite_generated)
    if $job == null {
        let existing = (existing-active-job $note.note_id $source_hash)
        print $"Already queued: ($existing.job_id? | default 'unknown')"
        return
    }

    log-event $note.note_id 'reingest-enqueued' {
        job_id: $job.job_id
        source_hash: $source_hash
        archive_path: $archive_path
        force_overwrite_generated: $force_overwrite_generated
    }

    print $"Enqueued ($job.job_id) for ($note.note_id)"

    try {
        worker-run --drain
    } catch {|error|
        error make {
            msg: (($error.msg? | default ($error | to nuon)) | into string)
        }
    }
}


def main [note_id: string, --latest-source, --latest-archive, --force-overwrite-generated] {
    ensure-layout

    let note_row = (sql-json $"
        select *
        from notes
        where note_id = (sql-quote $note_id)
        limit 1;
    " | first)
    let note = if $note_row == null {
        null
    } else {
        $note_row | upsert source_path ([ (webdav-root) $note_row.source_relpath ] | path join)
    }

    if $note == null {
        error make {
            msg: $"Unknown note id: ($note_id)"
        }
    }

    if $latest_source and $latest_archive {
        error make {
            msg: 'Choose only one of --latest-source or --latest-archive'
        }
    }

    let source_mode = if $latest_source {
        'source'
    } else if $latest_archive {
        'archive'
    } else if ($note.status == 'active' and ($note.source_path | path exists)) {
        'source'
    } else {
        'archive'
    }

    if $source_mode == 'source' {
        let archived = (archive-current-source $note)
        enqueue-reingest-job $note $archived.source_hash $archived.input_path $archived.archive_path $force_overwrite_generated
        return
    }

    let version = (latest-version $note.note_id)
    if $version == null {
        error make {
            msg: $"No archived version found for ($note.note_id)"
        }
    }

    enqueue-reingest-job $note $version.source_hash $version.archive_path $version.archive_path $force_overwrite_generated
}
