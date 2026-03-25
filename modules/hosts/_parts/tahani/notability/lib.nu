export def home-dir [] {
    $nu.home-dir
}

export def data-root [] {
    if ('NOTABILITY_DATA_ROOT' in ($env | columns)) {
        $env.NOTABILITY_DATA_ROOT
    } else {
        [$nu.home-dir ".local" "share" "notability-ingest"] | path join
    }
}

export def state-root [] {
    if ('NOTABILITY_STATE_ROOT' in ($env | columns)) {
        $env.NOTABILITY_STATE_ROOT
    } else {
        [$nu.home-dir ".local" "state" "notability-ingest"] | path join
    }
}

export def notes-root [] {
    if ('NOTABILITY_NOTES_DIR' in ($env | columns)) {
        $env.NOTABILITY_NOTES_DIR
    } else {
        [$nu.home-dir "Notes"] | path join
    }
}

export def webdav-root [] {
    if ('NOTABILITY_WEBDAV_ROOT' in ($env | columns)) {
        $env.NOTABILITY_WEBDAV_ROOT
    } else {
        [(data-root) "webdav-root"] | path join
    }
}

export def archive-root [] {
    if ('NOTABILITY_ARCHIVE_ROOT' in ($env | columns)) {
        $env.NOTABILITY_ARCHIVE_ROOT
    } else {
        [(data-root) "archive"] | path join
    }
}

export def render-root [] {
    if ('NOTABILITY_RENDER_ROOT' in ($env | columns)) {
        $env.NOTABILITY_RENDER_ROOT
    } else {
        [(data-root) "rendered-pages"] | path join
    }
}

export def transcript-root [] {
    if ('NOTABILITY_TRANSCRIPT_ROOT' in ($env | columns)) {
        $env.NOTABILITY_TRANSCRIPT_ROOT
    } else {
        [(state-root) "transcripts"] | path join
    }
}

export def jobs-root [] {
    if ('NOTABILITY_JOBS_ROOT' in ($env | columns)) {
        $env.NOTABILITY_JOBS_ROOT
    } else {
        [(state-root) "jobs"] | path join
    }
}

export def queued-root [] {
    [(jobs-root) "queued"] | path join
}

export def running-root [] {
    [(jobs-root) "running"] | path join
}

export def failed-root [] {
    [(jobs-root) "failed"] | path join
}

export def done-root [] {
    [(jobs-root) "done"] | path join
}

export def results-root [] {
    [(jobs-root) "results"] | path join
}

export def sessions-root [] {
    if ('NOTABILITY_SESSIONS_ROOT' in ($env | columns)) {
        $env.NOTABILITY_SESSIONS_ROOT
    } else {
        [(state-root) "sessions"] | path join
    }
}

export def qmd-dirty-file [] {
    [(state-root) "qmd-dirty"] | path join
}

export def db-path [] {
    if ('NOTABILITY_DB_PATH' in ($env | columns)) {
        $env.NOTABILITY_DB_PATH
    } else {
        [(state-root) "db.sqlite"] | path join
    }
}

export def now-iso [] {
    date now | format date "%Y-%m-%dT%H:%M:%SZ"
}

export def sql-quote [value?: any] {
    if $value == null {
        "NULL"
    } else {
        let text = ($value | into string | str replace -a "'" "''")
        ["'" $text "'"] | str join ''
    }
}

export def sql-run [sql: string] {
    let database = (db-path)
    let result = (^sqlite3 -cmd '.timeout 5000' $database $sql | complete)
    if $result.exit_code != 0 {
        error make {
            msg: $"sqlite3 failed: ($result.stderr | str trim)"
        }
    }
    $result.stdout
}

export def sql-json [sql: string] {
    let database = (db-path)
    let result = (^sqlite3 -cmd '.timeout 5000' -json $database $sql | complete)
    if $result.exit_code != 0 {
        error make {
            msg: $"sqlite3 failed: ($result.stderr | str trim)"
        }
    }
    let text = ($result.stdout | str trim)
    if $text == "" {
        []
    } else {
        $text | from json
    }
}

export def ensure-layout [] {
    mkdir (data-root)
    mkdir (state-root)
    mkdir (notes-root)
    mkdir (webdav-root)
    mkdir (archive-root)
    mkdir (render-root)
    mkdir (transcript-root)
    mkdir (jobs-root)
    mkdir (queued-root)
    mkdir (running-root)
    mkdir (failed-root)
    mkdir (done-root)
    mkdir (results-root)
    mkdir (sessions-root)

    sql-run '
    create table if not exists notes (
        note_id text primary key,
        source_relpath text not null unique,
        title text not null,
        output_path text not null,
        status text not null,
        first_seen_at text not null,
        last_seen_at text not null,
        last_processed_at text,
        missing_since text,
        deleted_at text,
        current_source_hash text,
        current_source_size integer,
        current_source_mtime text,
        current_archive_path text,
        latest_version_id text,
        last_generated_source_hash text,
        last_generated_output_hash text,
        conflict_path text,
        last_error text
    );

    create table if not exists versions (
        version_id text primary key,
        note_id text not null,
        seen_at text not null,
        archive_path text not null unique,
        source_hash text not null,
        source_size integer not null,
        source_mtime text not null,
        source_relpath text not null,
        ingest_result text,
        session_path text,
        foreign key (note_id) references notes (note_id)
    );

    create table if not exists jobs (
        job_id text primary key,
        note_id text not null,
        operation text not null,
        status text not null,
        requested_at text not null,
        started_at text,
        finished_at text,
        source_hash text,
        job_manifest_path text not null,
        result_path text not null,
        error_summary text,
        foreign key (note_id) references notes (note_id)
    );

    create table if not exists events (
        id integer primary key autoincrement,
        note_id text not null,
        ts text not null,
        kind text not null,
        details text,
        foreign key (note_id) references notes (note_id)
    );

    create index if not exists idx_jobs_status_requested_at on jobs(status, requested_at);
    create index if not exists idx_versions_note_id_seen_at on versions(note_id, seen_at);
    create index if not exists idx_events_note_id_ts on events(note_id, ts);
    '
    | ignore
}

export def log-event [note_id: string, kind: string, details?: any] {
    let payload = if $details == null { null } else { $details | to json }
    let note_id_q = (sql-quote $note_id)
    let now_q = (sql-quote (now-iso))
    let kind_q = (sql-quote $kind)
    let payload_q = (sql-quote $payload)
    let sql = ([
        "insert into events (note_id, ts, kind, details) values ("
        $note_id_q
        ", "
        $now_q
        ", "
        $kind_q
        ", "
        $payload_q
        ");"
    ] | str join '')
    sql-run $sql | ignore
}

export def slugify [value: string] {
    let slug = (
        $value
        | str downcase
        | str replace -r '[^a-z0-9]+' '-'
        | str replace -r '^-+' ''
        | str replace -r '-+$' ''
    )
    if $slug == '' {
        'note'
    } else {
        $slug
    }
}

export def sha256 [file: path] {
    (^sha256sum $file | lines | first | split row ' ' | first)
}

export def parse-output-frontmatter [file: path] {
    if not ($file | path exists) {
        {}
    } else {
        let content = (open --raw $file)
        if not ($content | str starts-with "---\n") {
            {}
        } else {
            let rest = ($content | str substring 4..)
            let end = ($rest | str index-of "\n---\n")
            if $end == null {
                {}
            } else {
                let block = ($rest | str substring 0..($end - 1))
                $block
                | lines
                | where ($it | str contains ':')
                | reduce --fold {} {|line, acc|
                    let idx = ($line | str index-of ':')
                    if $idx == null {
                        $acc
                    } else {
                        let key = ($line | str substring 0..($idx - 1) | str trim)
                        let value = ($line | str substring ($idx + 1).. | str trim)
                        $acc | upsert $key $value
                    }
                }
            }
        }
    }
}

export def zk-generated-note-path [title: string] {
    let root = (notes-root)
    let effective_title = if ($title | str trim) == '' {
        'Imported note'
    } else {
        $title
    }
    let result = (
        ^zk --notebook-dir $root --working-dir $root new $root --no-input --title $effective_title --print-path --dry-run
        | complete
    )

    if $result.exit_code != 0 {
        error make {
            msg: $"zk failed to generate a note path: ($result.stderr | str trim)"
        }
    }

    let path_text = ($result.stderr | str trim)
    if $path_text == '' {
        error make {
            msg: 'zk did not return a generated note path'
        }
    }

    $path_text
    | lines
    | last
    | str trim
}

export def new-note-id [] {
    let suffix = (random uuid | str replace -a '-' '')
    $"ntl_($suffix)"
}

export def new-job-id [] {
    let suffix = (random uuid | str replace -a '-' '')
    $"job_($suffix)"
}

export def new-version-id [] {
    let suffix = (random uuid | str replace -a '-' '')
    $"ver_($suffix)"
}

export def archive-path-for [note_id: string, source_hash: string, source_relpath: string] {
    let stamp = (date now | format date "%Y-%m-%dT%H-%M-%SZ")
    let short = ($source_hash | str substring 0..11)
    let directory = [(archive-root) $note_id] | path join
    let parsed = ($source_relpath | path parse)
    let extension = if (($parsed.extension? | default '') | str trim) == '' {
        'bin'
    } else {
        ($parsed.extension | str downcase)
    }
    mkdir $directory
    [$directory $"($stamp)-($short).($extension)"] | path join
}

export def transcript-path-for [note_id: string, job_id: string] {
    let directory = [(transcript-root) $note_id] | path join
    mkdir $directory
    [$directory $"($job_id).md"] | path join
}

export def result-path-for [job_id: string] {
    [(results-root) $"($job_id).json"] | path join
}

export def manifest-path-for [job_id: string, status: string] {
    let root = match $status {
        'queued' => (queued-root)
        'running' => (running-root)
        'failed' => (failed-root)
        'done' => (done-root)
        _ => (queued-root)
    }
    [$root $"($job_id).json"] | path join
}

export def note-output-path [title: string] {
    zk-generated-note-path $title
}

export def is-supported-source-path [path: string] {
    let lower = ($path | str downcase)
    (($lower | str ends-with '.pdf') or ($lower | str ends-with '.png'))
}

export def is-ignored-path [relpath: string] {
    let lower = ($relpath | str downcase)
    let hidden = (($lower | str contains '/.') or ($lower | str starts-with '.'))
    let temp = (($lower | str contains '/~') or ($lower | str ends-with '.tmp') or ($lower | str ends-with '.part'))
    let conflict = ($lower | str contains '.sync-conflict')
    ($hidden or $temp or $conflict)
}

export def scan-source-files [] {
    let root = (webdav-root)
    if not ($root | path exists) {
        []
    } else {
        let files = ([
            (glob $"($root)/**/*.pdf")
            (glob $"($root)/**/*.PDF")
            (glob $"($root)/**/*.png")
            (glob $"($root)/**/*.PNG")
        ] | flatten)
        $files
        | sort
        | uniq
        | each {|file|
            let relpath = ($file | path relative-to $root)
            if ((is-ignored-path $relpath) or not (is-supported-source-path $file)) {
                null
            } else {
                let stat = (ls -l $file | first)
                {
                    source_path: $file
                    source_relpath: $relpath
                    source_size: $stat.size
                    source_mtime: ($stat.modified | format date "%Y-%m-%dT%H:%M:%SZ")
                    title: (($relpath | path parse).stem)
                }
            }
        }
        | where $it != null
    }
}
