#!/usr/bin/env nu

use ./lib.nu *
use ./jobs.nu [archive-and-version, enqueue-job]

const settle_window = 45sec
const delete_grace = 15min


def settle-remaining [source_mtime: string] {
    let modified = ($source_mtime | into datetime)
    let age = ((date now) - $modified)
    if $age >= $settle_window {
        0sec
    } else {
        $settle_window - $age
    }
}


def is-settled [source_mtime: string] {
    let modified = ($source_mtime | into datetime)
    ((date now) - $modified) >= $settle_window
}


def log-job-enqueued [note_id: string, job_id: string, operation: string, source_hash: string, archive_path: string] {
    log-event $note_id 'job-enqueued' {
        job_id: $job_id
        operation: $operation
        source_hash: $source_hash
        archive_path: $archive_path
    }
}


def find-rename-candidate [source_hash: string] {
    sql-json $"
        select *
        from notes
        where current_source_hash = (sql-quote $source_hash)
          and status != 'active'
          and status != 'failed'
          and status != 'conflict'
        order by last_seen_at desc
        limit 1;
    "
}


def touch-note [note_id: string, source_size: any, source_mtime: string, status: string = 'active'] {
	let source_size_int = ($source_size | into int)
	let now_q = (sql-quote (now-iso))
	let source_mtime_q = (sql-quote $source_mtime)
	let status_q = (sql-quote $status)
	let note_id_q = (sql-quote $note_id)
    sql-run $"
        update notes
        set last_seen_at = ($now_q),
            current_source_size = ($source_size_int),
            current_source_mtime = ($source_mtime_q),
            status = ($status_q)
        where note_id = ($note_id_q);
    "
    | ignore
}


def process-existing [note: record, source: record] {
    let title = $source.title
    let note_id = ($note | get note_id)
    let note_status = ($note | get status)
	let source_size_int = ($source.source_size | into int)
    if not (is-settled $source.source_mtime) {
        touch-note $note_id $source_size_int $source.source_mtime $note_status
        return
    }

    let previous_size = ($note.current_source_size? | default (-1))
    let previous_mtime = ($note.current_source_mtime? | default '')
    let size_changed = ($previous_size != $source_size_int)
    let mtime_changed = ($previous_mtime != $source.source_mtime)
    let needs_ingest = (($note.last_generated_source_hash? | default '') != ($note.current_source_hash? | default ''))
    let hash_needed = ($note.current_source_hash? | default null) == null or $size_changed or $mtime_changed or ($note_status != 'active') or $needs_ingest

    if not $hash_needed {
		let now_q = (sql-quote (now-iso))
		let title_q = (sql-quote $title)
		let note_id_q = (sql-quote $note_id)
        sql-run $"
            update notes
            set last_seen_at = ($now_q),
                status = 'active',
                title = ($title_q),
                missing_since = null,
                deleted_at = null
            where note_id = ($note_id_q);
        "
        | ignore
        return
    }

    let source_hash = (sha256 $source.source_path)
    if ($source_hash == ($note.current_source_hash? | default '')) {
		let now_q = (sql-quote (now-iso))
		let title_q = (sql-quote $title)
		let source_mtime_q = (sql-quote $source.source_mtime)
		let note_id_q = (sql-quote $note_id)
        let next_status = if $note_status == 'failed' { 'failed' } else { 'active' }
        sql-run $"
            update notes
            set last_seen_at = ($now_q),
                title = ($title_q),
                status = (sql-quote $next_status),
                missing_since = null,
                deleted_at = null,
                current_source_size = ($source_size_int),
                current_source_mtime = ($source_mtime_q)
            where note_id = ($note_id_q);
        "
        | ignore

        let should_enqueue = ($note_status == 'failed' or (($note.last_generated_source_hash? | default '') != $source_hash))
        if not $should_enqueue {
            return
        }

        let archive_path = if (($note.current_archive_path? | default '') | str trim) == '' {
            let version = (archive-and-version $note_id $source.source_path $source.source_relpath $source_size_int $source.source_mtime $source_hash)
            let archive_path_q = (sql-quote $version.archive_path)
            let version_id_q = (sql-quote $version.version_id)
            sql-run $"
                update notes
                set current_archive_path = ($archive_path_q),
                    latest_version_id = ($version_id_q)
                where note_id = ($note_id_q);
            "
            | ignore
            $version.archive_path
        } else {
            $note.current_archive_path
        }

        let runtime_note = ($note | upsert source_path $source.source_path | upsert source_relpath $source.source_relpath | upsert output_path $note.output_path | upsert last_generated_output_hash ($note.last_generated_output_hash? | default null))
        let retry_job = (enqueue-job $runtime_note 'upsert' $archive_path $archive_path $source_hash $title)
        if $retry_job != null {
            log-job-enqueued $note_id $retry_job.job_id 'upsert' $source_hash $archive_path
            let reason = if $note_status == 'failed' {
                'retry-failed-note'
            } else {
                'missing-generated-output'
            }
            log-event $note_id 'job-reenqueued' {
                job_id: $retry_job.job_id
                reason: $reason
                source_hash: $source_hash
                archive_path: $archive_path
            }
        }
        return
    }

    let version = (archive-and-version $note_id $source.source_path $source.source_relpath $source_size_int $source.source_mtime $source_hash)
	let now_q = (sql-quote (now-iso))
	let title_q = (sql-quote $title)
	let source_hash_q = (sql-quote $source_hash)
	let source_mtime_q = (sql-quote $source.source_mtime)
	let archive_path_q = (sql-quote $version.archive_path)
	let version_id_q = (sql-quote $version.version_id)
	let note_id_q = (sql-quote $note_id)
    sql-run $"
        update notes
        set last_seen_at = ($now_q),
            title = ($title_q),
            status = 'active',
            missing_since = null,
            deleted_at = null,
            current_source_hash = ($source_hash_q),
            current_source_size = ($source_size_int),
            current_source_mtime = ($source_mtime_q),
            current_archive_path = ($archive_path_q),
            latest_version_id = ($version_id_q),
            last_error = null
        where note_id = ($note_id_q);
    "
    | ignore

    let runtime_note = ($note | upsert source_path $source.source_path | upsert source_relpath $source.source_relpath | upsert output_path $note.output_path | upsert last_generated_output_hash ($note.last_generated_output_hash? | default null))
    let job = (enqueue-job $runtime_note 'upsert' $version.archive_path $version.archive_path $source_hash $title)
    if $job != null {
        log-job-enqueued $note_id $job.job_id 'upsert' $source_hash $version.archive_path
    }

    log-event $note_id 'source-updated' {
        source_relpath: $source.source_relpath
        source_hash: $source_hash
        archive_path: $version.archive_path
    }
}


def process-new [source: record] {
    if not (is-settled $source.source_mtime) {
        return
    }

    let source_hash = (sha256 $source.source_path)
	let source_size_int = ($source.source_size | into int)
    let rename_candidates = (find-rename-candidate $source_hash)
    if not ($rename_candidates | is-empty) {
		let rename_candidate = ($rename_candidates | first)
		let source_relpath_q = (sql-quote $source.source_relpath)
		let title_q = (sql-quote $source.title)
		let now_q = (sql-quote (now-iso))
		let source_mtime_q = (sql-quote $source.source_mtime)
		let note_id_q = (sql-quote $rename_candidate.note_id)
        sql-run $"
            update notes
            set source_relpath = ($source_relpath_q),
                title = ($title_q),
                last_seen_at = ($now_q),
                status = 'active',
                missing_since = null,
                deleted_at = null,
                current_source_size = ($source_size_int),
                current_source_mtime = ($source_mtime_q)
            where note_id = ($note_id_q);
        "
        | ignore
        log-event $rename_candidate.note_id 'source-renamed' {
            from: $rename_candidate.source_relpath
            to: $source.source_relpath
        }
        return
    }

    let note_id = (new-note-id)
    let first_seen_at = (now-iso)
    let output_path = (note-output-path $source.title)
    let version = (archive-and-version $note_id $source.source_path $source.source_relpath $source_size_int $source.source_mtime $source_hash)
	let note_id_q = (sql-quote $note_id)
	let source_relpath_q = (sql-quote $source.source_relpath)
	let title_q = (sql-quote $source.title)
	let output_path_q = (sql-quote $output_path)
	let first_seen_q = (sql-quote $first_seen_at)
	let source_hash_q = (sql-quote $source_hash)
	let source_mtime_q = (sql-quote $source.source_mtime)
	let archive_path_q = (sql-quote $version.archive_path)
	let version_id_q = (sql-quote $version.version_id)
	let sql = ([
		"insert into notes (note_id, source_relpath, title, output_path, status, first_seen_at, last_seen_at, current_source_hash, current_source_size, current_source_mtime, current_archive_path, latest_version_id) values ("
		$note_id_q
		", "
		$source_relpath_q
		", "
		$title_q
		", "
		$output_path_q
		", 'active', "
		$first_seen_q
		", "
		$first_seen_q
		", "
		$source_hash_q
		", "
		($source_size_int | into string)
		", "
		$source_mtime_q
		", "
		$archive_path_q
		", "
		$version_id_q
		");"
	] | str join '')
	sql-run $sql | ignore

    let note = {
        note_id: $note_id
        source_relpath: $source.source_relpath
        source_path: $source.source_path
        output_path: $output_path
        last_generated_output_hash: null
    }
    let job = (enqueue-job $note 'upsert' $version.archive_path $version.archive_path $source_hash $source.title)
    if $job != null {
        log-job-enqueued $note_id $job.job_id 'upsert' $source_hash $version.archive_path
    }

    log-event $note_id 'source-discovered' {
        source_relpath: $source.source_relpath
        source_hash: $source_hash
        archive_path: $version.archive_path
        output_path: $output_path
    }
}


def mark-missing [seen_relpaths: list<string>] {
    let notes = (sql-json 'select note_id, source_relpath, status, missing_since from notes;')
    for note in $notes {
        if ($seen_relpaths | any {|rel| $rel == $note.source_relpath }) {
            continue
        }

        if $note.status == 'active' {
            let missing_since = (now-iso)
			let missing_since_q = (sql-quote $missing_since)
			let note_id_q = (sql-quote $note.note_id)
            sql-run $"
                update notes
                set status = 'source_missing',
                    missing_since = ($missing_since_q)
                where note_id = ($note_id_q);
            "
            | ignore
            log-event $note.note_id 'source-missing' {
                source_relpath: $note.source_relpath
            }
            continue
        }

        if $note.status == 'source_missing' and ($note.missing_since? | default null) != null {
            let missing_since = ($note.missing_since | into datetime)
            if ((date now) - $missing_since) >= $delete_grace {
                let deleted_at = (now-iso)
				let deleted_at_q = (sql-quote $deleted_at)
				let note_id_q = (sql-quote $note.note_id)
                sql-run $"
                    update notes
                    set status = 'source_deleted',
                        deleted_at = ($deleted_at_q)
                    where note_id = ($note_id_q);
                "
                | ignore
                log-event $note.note_id 'source-deleted' {
                    source_relpath: $note.source_relpath
                }
            }
        }
    }
}


export def reconcile-run [] {
    ensure-layout
    mut sources = (scan-source-files)

    let unsettled = (
        $sources
        | each {|source|
            {
                source_path: $source.source_path
                remaining: (settle-remaining $source.source_mtime)
            }
        }
        | where remaining > 0sec
    )

    if not ($unsettled | is-empty) {
        let max_remaining = ($unsettled | get remaining | math max)
        print $"Waiting ($max_remaining) for recent Notability uploads to settle"
        sleep ($max_remaining + 2sec)
        $sources = (scan-source-files)
    }

    for source in $sources {
        let existing_rows = (sql-json $"
            select *
            from notes
            where source_relpath = (sql-quote $source.source_relpath)
            limit 1;
        ")
        if (($existing_rows | length) == 0) {
            process-new $source
        } else {
            let existing = ($existing_rows | first)
            process-existing ($existing | upsert source_path $source.source_path) $source
        }
    }

    mark-missing ($sources | get source_relpath)
}


def main [] {
    reconcile-run
}
