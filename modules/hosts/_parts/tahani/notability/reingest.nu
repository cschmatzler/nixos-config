#!/usr/bin/env nu

use ./lib.nu *

const script_dir = (path self | path dirname)


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


def active-job-exists [note_id: string, source_hash: string] {
    let rows = (sql-json $"
        select job_id
        from jobs
        where note_id = (sql-quote $note_id)
          and source_hash = (sql-quote $source_hash)
          and status != 'done'
          and status != 'failed'
        limit 1;
    ")
    not ($rows | is-empty)
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
	let archive_path = (archive-path-for $note.note_id $source_hash $note.source_relpath)
	cp $note.source_path $archive_path

	let version_id = (new-version-id)
	let seen_at = (now-iso)
	let version_id_q = (sql-quote $version_id)
	let note_id_q = (sql-quote $note.note_id)
	let seen_at_q = (sql-quote $seen_at)
	let archive_path_q = (sql-quote $archive_path)
	let source_hash_q = (sql-quote $source_hash)
	let source_mtime_q = (sql-quote $source_mtime)
	let source_relpath_q = (sql-quote $note.source_relpath)
	let insert_sql = ([
		"insert into versions (version_id, note_id, seen_at, archive_path, source_hash, source_size, source_mtime, source_relpath, ingest_result, session_path) values ("
		$version_id_q
		", "
		$note_id_q
		", "
		$seen_at_q
		", "
		$archive_path_q
		", "
		$source_hash_q
		", "
		($source_size | into string)
		", "
		$source_mtime_q
		", "
		$source_relpath_q
		", 'pending', null);"
	] | str join '')
	sql-run $insert_sql | ignore

    sql-run $"
        update notes
        set current_source_hash = (sql-quote $source_hash),
            current_source_size = ($source_size),
            current_source_mtime = (sql-quote $source_mtime),
            current_archive_path = (sql-quote $archive_path),
            latest_version_id = (sql-quote $version_id),
            last_seen_at = (sql-quote (now-iso)),
            status = 'active',
            missing_since = null,
            deleted_at = null
        where note_id = (sql-quote $note.note_id);
    "
    | ignore

    {
        input_path: $archive_path
        archive_path: $archive_path
        source_hash: $source_hash
    }
}


def enqueue-job [note: record, source_hash: string, input_path: string, archive_path: string, force_overwrite_generated: bool] {
    if (active-job-exists $note.note_id $source_hash) {
        let existing = (sql-json $"
            select job_id
            from jobs
            where note_id = (sql-quote $note.note_id)
              and source_hash = (sql-quote $source_hash)
              and status != 'done'
              and status != 'failed'
            order by requested_at desc
            limit 1;
        " | first)
        print $"Already queued: ($existing.job_id)"
        return
    }

    let job_id = (new-job-id)
    let requested_at = (now-iso)
    let manifest_path = (manifest-path-for $job_id 'queued')
    let result_path = (result-path-for $job_id)
    let transcript_path = (transcript-path-for $note.note_id $job_id)
    let session_dir = ([(sessions-root) $note.note_id $job_id] | path join)
    mkdir $session_dir

	let manifest = {
        version: 1
        job_id: $job_id
        note_id: $note.note_id
        operation: 'reingest'
        requested_at: $requested_at
        title: $note.title
        source_relpath: $note.source_relpath
        source_path: $note.source_path
        input_path: $input_path
        archive_path: $archive_path
        output_path: $note.output_path
        transcript_path: $transcript_path
        result_path: $result_path
        session_dir: $session_dir
        source_hash: $source_hash
        last_generated_output_hash: ($note.last_generated_output_hash? | default null)
        force_overwrite_generated: $force_overwrite_generated
        source_transport: 'webdav'
	}

	($manifest | to json --indent 2) | save -f $manifest_path
	let job_id_q = (sql-quote $job_id)
	let note_id_q = (sql-quote $note.note_id)
	let requested_at_q = (sql-quote $requested_at)
	let source_hash_q = (sql-quote $source_hash)
	let manifest_path_q = (sql-quote $manifest_path)
	let result_path_q = (sql-quote $result_path)
	let sql = ([
		"insert into jobs (job_id, note_id, operation, status, requested_at, source_hash, job_manifest_path, result_path) values ("
		$job_id_q
		", "
		$note_id_q
		", 'reingest', 'queued', "
		$requested_at_q
		", "
		$source_hash_q
		", "
		$manifest_path_q
		", "
		$result_path_q
		");"
	] | str join '')
	sql-run $sql | ignore

    log-event $note.note_id 'reingest-enqueued' {
        job_id: $job_id
        source_hash: $source_hash
        archive_path: $archive_path
        force_overwrite_generated: $force_overwrite_generated
    }

    print $"Enqueued ($job_id) for ($note.note_id)"

    let worker_script = ([ $script_dir 'worker.nu' ] | path join)
    let worker_result = (^nu $worker_script --drain | complete)
    if $worker_result.exit_code != 0 {
        error make {
            msg: $"worker drain failed: ($worker_result.stderr | str trim)"
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
        enqueue-job $note $archived.source_hash $archived.input_path $archived.archive_path $force_overwrite_generated
        return
    }

    let version = (latest-version $note.note_id)
    if $version == null {
        error make {
            msg: $"No archived version found for ($note.note_id)"
        }
    }

    enqueue-job $note $version.source_hash $version.archive_path $version.archive_path $force_overwrite_generated
}
