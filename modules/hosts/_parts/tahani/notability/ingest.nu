#!/usr/bin/env nu

use ./lib.nu *

const vision_model = 'openai-codex/gpt-5.4'


def call-pi [prompt: string, inputs: list<path>, thinking: string] {
    let prompt_file = (^mktemp --suffix '.md' | str trim)
    $prompt | save -f $prompt_file
    let input_refs = ($inputs | each {|f| $"'@($f)'"} | str join ' ')
    let cmd = $"timeout 45s pi --model '($vision_model)' --thinking ($thinking) --no-tools --no-session -p ($input_refs) '@($prompt_file)'"
    let result = (bash -c $cmd | complete)
    rm -f $prompt_file
    let output = ($result.stdout | str trim)
    if $output != '' {
        $output
    } else {
        error make { msg: $"pi returned no output \(exit ($result.exit_code)): ($result.stderr | str trim)" }
    }
}


def render-pages [input_path: path, job_id: string] {
    let ext = (([$input_path] | path parse | first).extension? | default '' | str downcase)
    if $ext == 'png' {
        [$input_path]
    } else if $ext == 'pdf' {
        let dir = [(render-root) $job_id] | path join
        mkdir $dir
        ^pdftoppm -png -r 200 $input_path ([$dir 'page'] | path join)
        (glob $"($dir)/*.png") | sort
    } else {
        error make { msg: $"Unsupported format: ($ext)" }
    }
}


def unquote [v?: any] {
    if $v == null { '' } else { $v | into string | str replace -r '^["''](.*)["'']$' '$1' }
}


def find-output [note_id: string, configured: path] {
    if ($configured | path exists) {
        let fm = (parse-output-frontmatter $configured)
        if (unquote ($fm.managed_by? | default '')) == 'notability-ingest' and (unquote ($fm.note_id? | default '')) == $note_id {
            return $configured
        }
    }
    let found = (glob $"((notes-root))/**/*.md") | where not ($it | str contains '/.') | where {|f|
        let fm = (parse-output-frontmatter $f)
        (unquote ($fm.managed_by? | default '')) == 'notability-ingest' and (unquote ($fm.note_id? | default '')) == $note_id
    }
    if ($found | is-empty) { $configured } else { $found | first }
}


def source-format [p: path] {
    ([$p] | path parse | first).extension? | default 'bin' | str downcase
}


def main [manifest_path: path] {
    ensure-layout
    let m = (open $manifest_path)

    # transcribe
    let pages = (render-pages $m.input_path $m.job_id)
    let transcript = (call-pi "Transcribe this note into clean Markdown. Read it like a human and preserve the intended reading order and visible structure. Keep headings, lists, and paragraphs when they are visible. Do not summarize. Do not add commentary. Return Markdown only." $pages 'low')

    mkdir ([$m.transcript_path] | path dirname)
    $"($transcript)\n" | save -f $m.transcript_path

    # normalize
    let normalized = (call-pi "Rewrite the attached transcription into clean Markdown. Preserve the same content and intended structure. Do not summarize. Return Markdown only." [$m.transcript_path] 'off')

    # build output
    let body = ($normalized | str trim)
    let body_out = if $body == '' { $"# ($m.title)" } else { $body }
    let created = ($m.requested_at | str substring 0..9)
    let updated = ((date now) | format date '%Y-%m-%d')
    let markdown = ([
        '---'
        $'title: ($m.title | to json)'
        $'created: ($created | to json)'
        $'updated: ($updated | to json)'
        'source: "notability"'
        $'source_transport: (($m.source_transport? | default "webdav") | to json)'
        $'source_relpath: ($m.source_relpath | to json)'
        $'note_id: ($m.note_id | to json)'
        'managed_by: "notability-ingest"'
        $'source_file: ($m.archive_path | to json)'
        $'source_file_hash: ($"sha256:($m.source_hash)" | to json)'
        $'source_format: ((source-format $m.archive_path) | to json)'
        'status: "active"'
        'tags:'
        '  - handwritten'
        '  - notability'
        '---'
        ''
        $body_out
        ''
    ] | str join "\n")

    # write
    let output_path = (find-output $m.note_id $m.output_path)
    let write_path = if ($m.force_overwrite_generated? | default false) or not ($output_path | path exists) {
        $output_path
    } else {
        let fm = (parse-output-frontmatter $output_path)
        if (unquote ($fm.managed_by? | default '')) == 'notability-ingest' and (unquote ($fm.note_id? | default '')) == $m.note_id {
            $output_path
        } else {
            let stamp = ((date now) | format date '%Y-%m-%dT%H-%M-%SZ')
            let parsed = ([$output_path] | path parse | first)
            [$parsed.parent $"($parsed.stem).conflict-($stamp).($parsed.extension)"] | path join
        }
    }
    let write_mode = if not ($output_path | path exists) { 'create' } else if $write_path == $output_path { 'overwrite' } else { 'conflict' }

    mkdir ([$write_path] | path dirname)
    $markdown | save -f $write_path

    let output_hash = (sha256 $write_path)

    # result
    {
        success: true
        job_id: $m.job_id
        note_id: $m.note_id
        archive_path: $m.archive_path
        source_hash: $m.source_hash
        session_dir: $m.session_dir
        output_path: $output_path
        output_hash: $output_hash
        write_mode: $write_mode
        updated_main_output: ($write_path == $output_path)
        transcript_path: $m.transcript_path
    } | to json --indent 2 | save -f $m.result_path
}
