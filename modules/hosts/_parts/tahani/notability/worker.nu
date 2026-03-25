#!/usr/bin/env nu

use ./lib.nu *

const qmd_debounce = 1min
const idle_sleep = 10sec
const vision_model = 'openai-codex/gpt-5.4'
const transcribe_timeout = '90s'
const normalize_timeout = '60s'


def next-queued-job [] {
    sql-json "
        select job_id, note_id, operation, job_manifest_path, result_path, source_hash
        from jobs
        where status = 'queued'
        order by requested_at asc
        limit 1;
    "
    | first
}


def maybe-update-qmd [] {
    let dirty = (qmd-dirty-file)
    if not ($dirty | path exists) {
        return
    }

    let modified = ((ls -l $dirty | first).modified)
    if ((date now) - $modified) < $qmd_debounce {
        return
    }

    print 'Running qmd update'
    let result = (do {
        cd (notes-root)
        run-external qmd 'update' | complete
    })
    if $result.exit_code != 0 {
        print $"qmd update failed: ($result.stderr | str trim)"
        return
    }

    rm -f $dirty
}


def write-result [result_path: path, payload: record] {
    mkdir ($result_path | path dirname)
    ($payload | to json --indent 2) | save -f $result_path
}


def error-message [error: any] {
    let msg = (($error.msg? | default '') | into string)
    if ($msg == '' or $msg == 'External command failed') {
        $error | to nuon
    } else {
        $msg
    }
}


def unquote [value?: any] {
    if $value == null {
        ''
    } else {
        ($value | into string | str replace -r '^"(.*)"$' '$1' | str replace -r "^'(.*)'$" '$1')
    }
}


def source-format [file: path] {
    (([$file] | path parse | first).extension? | default 'bin' | str downcase)
}


def conflict-path-for [output_path: path] {
    let parsed = ([$output_path] | path parse | first)
    let stamp = ((date now) | format date '%Y-%m-%dT%H-%M-%SZ')
    [$parsed.parent $"($parsed.stem).conflict-($stamp).($parsed.extension)"] | path join
}


def find-managed-outputs [note_id: string] {
    let root = (notes-root)
    if not ($root | path exists) {
        []
    } else {
        (glob $"($root)/**/*.md")
        | where not ($it | str contains '/.')
        | where {|file|
            let parsed = (parse-output-frontmatter $file)
            (unquote ($parsed.managed_by? | default '')) == 'notability-ingest' and (unquote ($parsed.note_id? | default '')) == $note_id
        }
        | sort
    }
}


def resolve-managed-output-path [note_id: string, configured_output_path: path] {
    if ($configured_output_path | path exists) {
        let parsed = (parse-output-frontmatter $configured_output_path)
        let managed_by = (unquote ($parsed.managed_by? | default ''))
        let frontmatter_note_id = (unquote ($parsed.note_id? | default ''))
        if ($managed_by == 'notability-ingest' and $frontmatter_note_id == $note_id) {
            return $configured_output_path
        }
    }

    let discovered = (find-managed-outputs $note_id)
    if ($discovered | is-empty) {
        $configured_output_path
    } else if (($discovered | length) == 1) {
        $discovered | first
    } else {
        error make {
            msg: $"Multiple managed note files found for ($note_id): (($discovered | str join ', '))"
        }
    }
}


def determine-write-target [manifest: record] {
    let output_path = (resolve-managed-output-path $manifest.note_id $manifest.output_path)
    if not ($output_path | path exists) {
        return {
            output_path: $output_path
            write_path: $output_path
            write_mode: 'create'
            updated_main_output: true
        }
    }

    let parsed = (parse-output-frontmatter $output_path)
    let managed_by = (unquote ($parsed.managed_by? | default ''))
    let frontmatter_note_id = (unquote ($parsed.note_id? | default ''))
    if ($managed_by == 'notability-ingest' and $frontmatter_note_id == $manifest.note_id) {
        return {
            output_path: $output_path
            write_path: $output_path
            write_mode: 'overwrite'
            updated_main_output: true
        }
    }

    {
        output_path: $output_path
        write_path: (conflict-path-for $output_path)
        write_mode: 'conflict'
        updated_main_output: false
    }
}


def build-markdown [manifest: record, normalized: string] {
    let body = ($normalized | str trim)
    let output_body = if $body == '' {
        $"# ($manifest.title)"
    } else {
        $body
    }
    let created = ($manifest.requested_at | str substring 0..9)
    let updated = ((date now) | format date '%Y-%m-%d')

    [
        '---'
        $"title: ($manifest.title | to json)"
        $"created: ($created | to json)"
        $"updated: ($updated | to json)"
        'source: "notability"'
        $"source_transport: (($manifest.source_transport? | default 'webdav') | to json)"
        $"source_relpath: ($manifest.source_relpath | to json)"
        $"note_id: ($manifest.note_id | to json)"
        'managed_by: "notability-ingest"'
        $"source_file: ($manifest.archive_path | to json)"
        $"source_file_hash: ($'sha256:($manifest.source_hash)' | to json)"
        $"source_format: ((source-format $manifest.archive_path) | to json)"
        'status: "active"'
        'tags:'
        '  - handwritten'
        '  - notability'
        '---'
        ''
        $output_body
        ''
    ] | str join "\n"
}


def render-pages [input_path: path, job_id: string] {
    let extension = (([$input_path] | path parse | first).extension? | default '' | str downcase)
    if $extension == 'png' {
        [ $input_path ]
    } else if $extension == 'pdf' {
        let render_dir = [(render-root) $job_id] | path join
        mkdir $render_dir
        let prefix = [$render_dir 'page'] | path join
        ^pdftoppm -png -r 200 $input_path $prefix
        let pages = ((glob $"($render_dir)/*.png") | sort)
        if ($pages | is-empty) {
            error make {
                msg: $"No PNG pages rendered from ($input_path)"
            }
        }
        $pages
    } else {
        error make {
            msg: $"Unsupported Notability input format: ($input_path)"
        }
    }
}


def call-pi [timeout_window: string, prompt: string, inputs: list<path>, thinking: string] {
    let prompt_file = (^mktemp --suffix '.md' | str trim)
    $prompt | save -f $prompt_file
    let input_refs = ($inputs | each {|input| $'@($input)' })
    let prompt_ref = $'@($prompt_file)'
    let result = (try {
        ^timeout $timeout_window pi --model $vision_model --thinking $thinking --no-tools --no-session -p ...$input_refs $prompt_ref | complete
    } catch {|error|
        rm -f $prompt_file
        error make {
            msg: (error-message $error)
        }
    })
    rm -f $prompt_file

    let output = ($result.stdout | str trim)
    if $output != '' {
        $output
    } else {
        let stderr = ($result.stderr | str trim)
        if $stderr == '' {
            error make {
                msg: $"pi returned no output (exit ($result.exit_code))"
            }
        } else {
            error make {
                msg: $"pi returned no output (exit ($result.exit_code)): ($stderr)"
            }
        }
    }
}


def ingest-job [manifest: record] {
    mkdir $manifest.session_dir

    let page_paths = (render-pages $manifest.input_path $manifest.job_id)
    let transcribe_prompt = ([
        'Transcribe this note into clean Markdown.'
        ''
        'Read it like a human and reconstruct the intended reading order and structure.'
        ''
        'Do not preserve handwritten layout literally.'
        ''
        'Handwritten line breaks, word stacking, font size changes, and spacing are not semantic structure by default.'
        ''
        'If adjacent handwritten lines clearly belong to one sentence or short phrase, merge them into normal prose with spaces instead of separate Markdown lines.'
        ''
        'Only keep separate lines or blank lines when there is clear evidence of separate paragraphs, headings, list items, checkboxes, or other distinct blocks.'
        ''
        'Keep headings, lists, and paragraphs when they are genuinely present.'
        ''
        'Do not summarize. Do not add commentary. Return Markdown only.'
    ] | str join "\n")
    print $"Transcribing ($manifest.job_id) with page count ($page_paths | length)"
    let transcript = (call-pi $transcribe_timeout $transcribe_prompt $page_paths 'low')
    mkdir ($manifest.transcript_path | path dirname)
    $"($transcript)\n" | save -f $manifest.transcript_path

    let normalize_prompt = ([
        'Rewrite the attached transcription into clean Markdown.'
        ''
        'Preserve the same content and intended structure.'
        ''
        'Collapse layout-only line breaks from handwriting.'
        ''
        'If short adjacent lines are really one sentence or phrase, join them with spaces instead of keeping one line per handwritten row.'
        ''
        'Use separate lines only for real headings, list items, checkboxes, or distinct paragraphs.'
        ''
        'Do not summarize. Return Markdown only.'
    ] | str join "\n")
    print $"Normalizing ($manifest.job_id)"
    let normalized = (call-pi $normalize_timeout $normalize_prompt [ $manifest.transcript_path ] 'off')

    let markdown = (build-markdown $manifest $normalized)
    let target = (determine-write-target $manifest)
    mkdir ($target.write_path | path dirname)
    $markdown | save -f $target.write_path

    {
        success: true
        job_id: $manifest.job_id
        note_id: $manifest.note_id
        archive_path: $manifest.archive_path
        source_hash: $manifest.source_hash
        session_dir: $manifest.session_dir
        output_path: $target.output_path
        output_hash: (if $target.updated_main_output { sha256 $target.write_path } else { null })
        conflict_path: (if $target.write_mode == 'conflict' { $target.write_path } else { null })
        write_mode: $target.write_mode
        updated_main_output: $target.updated_main_output
        transcript_path: $manifest.transcript_path
    }
}


def mark-failure [job: record, running_path: string, error_summary: string, result?: any] {
    let finished_at = (now-iso)
    sql-run $"
        update jobs
        set status = 'failed',
            finished_at = (sql-quote $finished_at),
            error_summary = (sql-quote $error_summary),
            job_manifest_path = (sql-quote (manifest-path-for $job.job_id 'failed'))
        where job_id = (sql-quote $job.job_id);

        update notes
        set status = 'failed',
            last_error = (sql-quote $error_summary)
        where note_id = (sql-quote $job.note_id);
    "
    | ignore

    if $result != null and ($result.archive_path? | default null) != null {
        sql-run $"
            update versions
            set ingest_result = 'failed',
                session_path = (sql-quote ($result.session_dir? | default ''))
            where archive_path = (sql-quote $result.archive_path);
        "
        | ignore
    }

    let failed_path = (manifest-path-for $job.job_id 'failed')
    if ($running_path | path exists) {
        mv -f $running_path $failed_path
    }

    log-event $job.note_id 'job-failed' {
        job_id: $job.job_id
        error: $error_summary
    }
}


def mark-success [job: record, running_path: string, result: record] {
    let finished_at = (now-iso)
    let note_status = if ($result.write_mode? | default 'write') == 'conflict' {
        'conflict'
    } else {
        'active'
    }
    let output_path_q = (sql-quote ($result.output_path? | default null))
    let output_hash_update = if ($result.updated_main_output? | default false) {
        sql-quote ($result.output_hash? | default null)
    } else {
        'last_generated_output_hash'
    }
    let source_hash_update = if ($result.updated_main_output? | default false) {
        sql-quote ($result.source_hash? | default null)
    } else {
        'last_generated_source_hash'
    }

    sql-run $"
        update jobs
        set status = 'done',
            finished_at = (sql-quote $finished_at),
            error_summary = null,
            job_manifest_path = (sql-quote (manifest-path-for $job.job_id 'done'))
        where job_id = (sql-quote $job.job_id);

        update notes
        set status = (sql-quote $note_status),
            output_path = ($output_path_q),
            last_processed_at = (sql-quote $finished_at),
            last_generated_output_hash = ($output_hash_update),
            last_generated_source_hash = ($source_hash_update),
            conflict_path = (sql-quote ($result.conflict_path? | default null)),
            last_error = null
        where note_id = (sql-quote $job.note_id);

        update versions
        set ingest_result = 'success',
            session_path = (sql-quote ($result.session_dir? | default ''))
        where archive_path = (sql-quote $result.archive_path);
    "
    | ignore

    let done_path = (manifest-path-for $job.job_id 'done')
    if ($running_path | path exists) {
        mv -f $running_path $done_path
    }

    ^touch (qmd-dirty-file)

    log-event $job.note_id 'job-finished' {
        job_id: $job.job_id
        write_mode: ($result.write_mode? | default 'write')
        output_path: ($result.output_path? | default '')
        conflict_path: ($result.conflict_path? | default '')
    }
}


def recover-running-jobs [] {
    let jobs = (sql-json "
        select job_id, note_id, job_manifest_path, result_path
        from jobs
        where status = 'running'
        order by started_at asc;
    ")

    for job in $jobs {
        let running_path = (manifest-path-for $job.job_id 'running')
        let result = if ($job.result_path | path exists) {
            open $job.result_path
        } else {
            null
        }
        mark-failure $job $running_path 'worker interrupted before completion' $result
    }
}


def process-job [job: record] {
    let running_path = (manifest-path-for $job.job_id 'running')
    mv -f $job.job_manifest_path $running_path
    sql-run $"
        update jobs
        set status = 'running',
            started_at = (sql-quote (now-iso)),
            job_manifest_path = (sql-quote $running_path)
        where job_id = (sql-quote $job.job_id);
    "
    | ignore

    print $"Processing ($job.job_id) for ($job.note_id)"

    let manifest = (open $running_path)
    try {
        let result = (ingest-job $manifest)
        write-result $job.result_path $result
        mark-success $job $running_path $result
    } catch {|error|
        let message = (error-message $error)
        let result = {
            success: false
            job_id: $manifest.job_id
            note_id: $manifest.note_id
            archive_path: $manifest.archive_path
            source_hash: $manifest.source_hash
            session_dir: $manifest.session_dir
            error: $message
        }
        write-result $job.result_path $result
        mark-failure $job $running_path $message $result
    }
}


def drain-queued-jobs [] {
    loop {
        let job = (next-queued-job)
        if $job == null {
            maybe-update-qmd
            break
        }

        process-job $job
        maybe-update-qmd
    }
}


export def worker-run [--drain] {
    ensure-layout
    recover-running-jobs
    if $drain {
        drain-queued-jobs
        return
    }

    while true {
        let job = (next-queued-job)
        if $job == null {
            maybe-update-qmd
            sleep $idle_sleep
            continue
        }

        process-job $job
        maybe-update-qmd
    }
}


def main [--drain] {
    worker-run --drain=$drain
}
