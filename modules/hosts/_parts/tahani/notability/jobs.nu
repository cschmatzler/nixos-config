#!/usr/bin/env nu

use ./lib.nu *


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


export def archive-and-version [note_id: string, source_path: path, source_relpath: string, source_size: any, source_mtime: string, source_hash: string] {
    let source_size_int = ($source_size | into int)
    let archive_path = (archive-path-for $note_id $source_hash $source_relpath)
    cp $source_path $archive_path

    let version_id = (new-version-id)
    let seen_at = (now-iso)
    let version_id_q = (sql-quote $version_id)
    let note_id_q = (sql-quote $note_id)
    let seen_at_q = (sql-quote $seen_at)
    let archive_path_q = (sql-quote $archive_path)
    let source_hash_q = (sql-quote $source_hash)
    let source_mtime_q = (sql-quote $source_mtime)
    let source_relpath_q = (sql-quote $source_relpath)
    let sql = ([
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
        ($source_size_int | into string)
        ", "
        $source_mtime_q
        ", "
        $source_relpath_q
        ", 'pending', null);"
    ] | str join '')
    sql-run $sql | ignore

    {
        version_id: $version_id
        seen_at: $seen_at
        archive_path: $archive_path
    }
}


export def enqueue-job [
    note: record,
    operation: string,
    input_path: string,
    archive_path: string,
    source_hash: string,
    title: string,
    force_overwrite_generated: bool = false,
    source_transport: string = 'webdav',
] {
    if (active-job-exists $note.note_id $source_hash) {
        return null
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
        operation: $operation
        requested_at: $requested_at
        title: $title
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
        source_transport: $source_transport
    }

    ($manifest | to json --indent 2) | save -f $manifest_path
    let job_id_q = (sql-quote $job_id)
    let note_id_q = (sql-quote $note.note_id)
    let operation_q = (sql-quote $operation)
    let requested_at_q = (sql-quote $requested_at)
    let source_hash_q = (sql-quote $source_hash)
    let manifest_path_q = (sql-quote $manifest_path)
    let result_path_q = (sql-quote $result_path)
    let sql = ([
        "insert into jobs (job_id, note_id, operation, status, requested_at, source_hash, job_manifest_path, result_path) values ("
        $job_id_q
        ", "
        $note_id_q
        ", "
        $operation_q
        ", 'queued', "
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

    {
        job_id: $job_id
        requested_at: $requested_at
        manifest_path: $manifest_path
        result_path: $result_path
        transcript_path: $transcript_path
        session_dir: $session_dir
    }
}
