local M = {}

local list_unpack = unpack

local CUSTOM_INSTRUCTIONS_KEY = 'review.customInstructions'
local MIN_CHANGE_REVIEW_OPTIONS = 10
local RECENT_PULL_REQUEST_LIMIT = 5
local PULL_REQUEST_MAX_AGE_DAYS = 7

local WORKING_COPY_PROMPT =
  'Review the current working-copy changes (including new files) and provide prioritized findings.'

local LOCAL_CHANGES_REVIEW_INSTRUCTIONS =
  'Also include local working-copy changes (including new files) on top of this bookmark. Use `jj status`, `jj diff --summary`, and `jj diff` so local fixes are part of this review cycle.'

local BASE_BOOKMARK_PROMPT_WITH_MERGE_BASE =
  "Review the code changes against the base bookmark '{baseBookmark}'. The merge-base change for this comparison is {mergeBaseChangeId}. Run `jj diff --from {mergeBaseChangeId} --to @` to inspect the changes relative to {baseBookmark}. Provide prioritized, actionable findings."

local BASE_BOOKMARK_PROMPT_FALLBACK =
  "Review the code changes against the base bookmark '{bookmark}'. Start by finding the merge-base revision between the working copy and {bookmark}, then run `jj diff --from <merge-base> --to @` to see what changes would land on the {bookmark} bookmark. Provide prioritized, actionable findings."

local CHANGE_PROMPT_WITH_TITLE =
  'Review the code changes introduced by change {changeId} ("{title}"). Provide prioritized, actionable findings.'

local CHANGE_PROMPT =
  'Review the code changes introduced by change {changeId}. Provide prioritized, actionable findings.'

local PULL_REQUEST_PROMPT =
  'Review pull request #{prNumber} ("{title}") against the base bookmark \'{baseBookmark}\'. The merge-base change for this comparison is {mergeBaseChangeId}. Run `jj diff --from {mergeBaseChangeId} --to @` to inspect the changes that would be merged. Provide prioritized, actionable findings.'

local PULL_REQUEST_PROMPT_FALLBACK =
  'Review pull request #{prNumber} ("{title}") against the base bookmark \'{baseBookmark}\'. Start by finding the merge-base revision between the working copy and {baseBookmark}, then run `jj diff --from <merge-base> --to @` to see the changes that would be merged. Provide prioritized, actionable findings.'

local FOLDER_REVIEW_PROMPT =
  'Review the code in the following paths: {paths}. This is a snapshot review (not a diff). Read the files directly in these paths and provide prioritized, actionable findings.'

local REVIEW_RUBRIC = [=[# Review Guidelines

You are acting as a code reviewer for a proposed code change made by another engineer.

Below are default guidelines for determining what to flag. These are not the final word - if you encounter more specific guidelines elsewhere (in a developer message, user message, file, or project review guidelines appended below), those override these general instructions.

## Determining what to flag

Flag issues that:
1. Meaningfully impact the accuracy, performance, security, or maintainability of the code.
2. Are discrete and actionable (not general issues or multiple combined issues).
3. Don't demand rigor inconsistent with the rest of the codebase.
4. Were introduced in the changes being reviewed (not pre-existing bugs).
5. The author would likely fix if aware of them.
6. Don't rely on unstated assumptions about the codebase or author's intent.
7. Have provable impact on other parts of the code - it is not enough to speculate that a change may disrupt another part, you must identify the parts that are provably affected.
8. Are clearly not intentional changes by the author.
9. Be particularly careful with untrusted user input and follow the specific guidelines to review.
10. Treat silent local error recovery (especially parsing/IO/network fallbacks) as high-signal review candidates unless there is explicit boundary-level justification.

## Untrusted User Input

1. Be careful with open redirects, they must always be checked to only go to trusted domains (?next_page=...)
2. Always flag SQL that is not parametrized
3. In systems with user supplied URL input, http fetches always need to be protected against access to local resources (intercept DNS resolver!)
4. Escape, don't sanitize if you have the option (eg: HTML escaping)

## Comment guidelines

1. Be clear about why the issue is a problem.
2. Communicate severity appropriately - don't exaggerate.
3. Be brief - at most 1 paragraph.
4. Keep code snippets under 3 lines, wrapped in inline code or code blocks.
5. Use ```suggestion blocks ONLY for concrete replacement code (minimal lines; no commentary inside the block). Preserve the exact leading whitespace of the replaced lines.
6. Explicitly state scenarios/environments where the issue arises.
7. Use a matter-of-fact tone - helpful AI assistant, not accusatory.
8. Write for quick comprehension without close reading.
9. Avoid excessive flattery or unhelpful phrases like "Great job...".

## Review priorities

1. Surface critical non-blocking human callouts (migrations, dependency churn, auth/permissions, compatibility, destructive operations) at the end.
2. Prefer simple, direct solutions over wrappers or abstractions without clear value.
3. Treat back pressure handling as critical to system stability.
4. Apply system-level thinking; flag changes that increase operational risk or on-call wakeups.
5. Ensure that errors are always checked against codes or stable identifiers, never error messages.

## Fail-fast error handling (strict)

When reviewing added or modified error handling, default to fail-fast behavior.

1. Evaluate every new or changed `try/catch`: identify what can fail and why local handling is correct at that exact layer.
2. Prefer propagation over local recovery. If the current scope cannot fully recover while preserving correctness, rethrow (optionally with context) instead of returning fallbacks.
3. Flag catch blocks that hide failure signals (e.g. returning `null`/`[]`/`false`, swallowing JSON parse failures, logging-and-continue, or "best effort" silent recovery).
4. JSON parsing/decoding should fail loudly by default. Quiet fallback parsing is only acceptable with an explicit compatibility requirement and clear tested behavior.
5. Boundary handlers (HTTP routes, CLI entrypoints, supervisors) may translate errors, but must not pretend success or silently degrade.
6. If a catch exists only to satisfy lint/style without real handling, treat it as a bug.
7. When uncertain, prefer crashing fast over silent degradation.

## Required human callouts (non-blocking, at the very end)

After findings/verdict, you MUST append this final section:

## Human Reviewer Callouts (Non-Blocking)

Include only applicable callouts (no yes/no lines):

- **This change adds a database migration:** <files/details>
- **This change introduces a new dependency:** <package(s)/details>
- **This change changes a dependency (or the lockfile):** <files/package(s)/details>
- **This change modifies auth/permission behavior:** <what changed and where>
- **This change introduces backwards-incompatible public schema/API/contract changes:** <what changed and where>
- **This change includes irreversible or destructive operations:** <operation and scope>

Rules for this section:
1. These are informational callouts for the human reviewer, not fix items.
2. Do not include them in Findings unless there is an independent defect.
3. These callouts alone must not change the verdict.
4. Only include callouts that apply to the reviewed change.
5. Keep each emitted callout bold exactly as written.
6. If none apply, write "- (none)".

## Priority levels

Tag each finding with a priority level in the title:
- [P0] - Drop everything to fix. Blocking release/operations. Only for universal issues that do not depend on assumptions about inputs.
- [P1] - Urgent. Should be addressed in the next cycle.
- [P2] - Normal. To be fixed eventually.
- [P3] - Low. Nice to have.

## Output format

Provide your findings in a clear, structured format:
1. List each finding with its priority tag, file location, and explanation.
2. Findings must reference locations that overlap with the actual diff - don't flag pre-existing code.
3. Keep line references as short as possible (avoid ranges over 5-10 lines; pick the most suitable subrange).
4. Provide an overall verdict: "correct" (no blocking issues) or "needs attention" (has blocking issues).
5. Ignore trivial style issues unless they obscure meaning or violate documented standards.
6. Do not generate a full PR fix - only flag issues and optionally provide short suggestion blocks.
7. End with the required "Human Reviewer Callouts (Non-Blocking)" section and all applicable bold callouts (no yes/no).

Output all findings the author would fix if they knew about them. If there are no qualifying findings, explicitly state the code looks good. Don't stop at the first finding - list every qualifying issue. Then append the required non-blocking callouts section.]=]

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO)
end

local function get_cwd()
  return vim.fn.getcwd()
end

local function normalize_custom_instructions(value)
  if type(value) ~= 'string' then
    return nil
  end

  local normalized = vim.trim(value)
  if normalized == '' then
    return nil
  end

  return normalized
end

local function replace_placeholder(template, placeholder, value)
  local replacement = tostring(value):gsub('%%', '%%%%')
  return template:gsub(placeholder, replacement)
end

local function bookmark_label(bookmark)
  if bookmark.remote then
    return string.format('%s@%s', bookmark.name, bookmark.remote)
  end

  return bookmark.name
end

local function bookmark_revset(bookmark)
  local quoted_name = vim.json.encode(bookmark.name)
  if bookmark.remote then
    return string.format('remote_bookmarks(exact:%s, exact:%s)', quoted_name, vim.json.encode(bookmark.remote))
  end

  return string.format('bookmarks(exact:%s)', quoted_name)
end

local function split_nonempty_lines(stdout)
  local lines = {}

  for _, line in ipairs(vim.split(stdout or '', '\n', { trimempty = true })) do
    local trimmed = vim.trim(line)
    if trimmed ~= '' then
      table.insert(lines, trimmed)
    end
  end

  return lines
end

local function parse_bookmarks(stdout)
  local seen = {}
  local bookmarks = {}

  for _, line in ipairs(split_nonempty_lines(stdout)) do
    local fields = vim.split(line, '\t', { plain = true })
    local name = vim.trim(fields[1] or '')
    local remote = vim.trim(fields[2] or '')
    local bookmark = {
      name = name,
      remote = remote ~= '' and remote or nil,
    }

    if bookmark.name ~= '' and bookmark.remote ~= 'git' then
      local key = string.format('%s@%s', bookmark.name, bookmark.remote or '')
      if not seen[key] then
        seen[key] = true
        table.insert(bookmarks, bookmark)
      end
    end
  end

  return bookmarks
end

local function parse_changes(stdout)
  local changes = {}

  for _, line in ipairs(split_nonempty_lines(stdout)) do
    local fields = vim.split(line, '\t', { plain = true })
    local change_id = fields[1]
    table.remove(fields, 1)
    table.insert(changes, {
      changeId = change_id,
      title = table.concat(fields, ' '),
    })
  end

  return changes
end

local function parse_pr_ref(ref)
  local trimmed = vim.trim(ref or '')
  if trimmed:match('^%d+$') then
    local num = tonumber(trimmed)
    if num and num > 0 then
      return num
    end
  end

  local url_num = trimmed:match('^https?://github%.com/[^/]+/[^/]+/pull/(%d+)')
    or trimmed:match('^github%.com/[^/]+/[^/]+/pull/(%d+)')
  if url_num then
    local num = tonumber(url_num)
    if num and num > 0 then
      return num
    end
  end

  return nil
end

local function parse_iso_timestamp(value)
  local ts = vim.fn.strptime('%Y-%m-%dT%H:%M:%SZ', value)
  if ts >= 0 then
    return ts
  end

  ts = vim.fn.strptime('%Y-%m-%dT%H:%M:%S%z', value)
  if ts >= 0 then
    return ts
  end

  return nil
end

local function format_relative_time(value)
  local timestamp = parse_iso_timestamp(value)
  if not timestamp then
    return nil
  end

  local delta_seconds = os.time() - timestamp
  local future = delta_seconds < 0
  local absolute_seconds = math.floor(math.abs(delta_seconds) + 0.5)

  if absolute_seconds < 60 then
    return future and 'in <1m' or 'just now'
  end

  local units = {
    { label = 'y', seconds = 60 * 60 * 24 * 365 },
    { label = 'mo', seconds = 60 * 60 * 24 * 30 },
    { label = 'd', seconds = 60 * 60 * 24 },
    { label = 'h', seconds = 60 * 60 },
    { label = 'm', seconds = 60 },
  }

  for _, unit in ipairs(units) do
    if absolute_seconds >= unit.seconds then
      local count = math.floor(absolute_seconds / unit.seconds)
      if future then
        return string.format('in %d%s', count, unit.label)
      end

      return string.format('%d%s ago', count, unit.label)
    end
  end

  return future and 'soon' or 'just now'
end

local function get_pull_request_updated_since_date(days)
  return os.date('!%Y-%m-%d', os.time() - (days * 24 * 60 * 60))
end

local function decode_json(stdout)
  local ok, parsed = pcall(vim.json.decode, stdout)
  if not ok then
    return nil
  end

  return parsed
end

local function parse_pull_requests(stdout)
  local parsed = decode_json(stdout)
  if type(parsed) ~= 'table' then
    return {}
  end

  local result = {}
  for _, entry in ipairs(parsed) do
    if type(entry) == 'table' then
      local pr_number = type(entry.number) == 'number' and entry.number or nil
      local title = type(entry.title) == 'string' and vim.trim(entry.title) or ''
      local updated_at = type(entry.updatedAt) == 'string' and vim.trim(entry.updatedAt) or ''

      if pr_number and title ~= '' and updated_at ~= '' then
        table.insert(result, {
          prNumber = pr_number,
          title = title,
          updatedAt = updated_at,
          reviewRequested = entry.reviewRequested == true,
          author = type(entry.author) == 'table' and type(entry.author.login) == 'string' and entry.author.login or nil,
          baseRefName = type(entry.baseRefName) == 'string' and normalize_custom_instructions(entry.baseRefName) or nil,
          headRefName = type(entry.headRefName) == 'string' and normalize_custom_instructions(entry.headRefName) or nil,
        })
      end
    end
  end

  return result
end

local function dedupe_pull_requests(pull_requests)
  local seen = {}
  local result = {}

  for _, pull_request in ipairs(pull_requests) do
    if not seen[pull_request.prNumber] then
      seen[pull_request.prNumber] = true
      table.insert(result, pull_request)
    end
  end

  return result
end

local function build_pull_request_option_description(pr)
  if pr.isManualEntry then
    return '(enter PR number or URL)'
  end

  local parts = { pr.reviewRequested and 'review requested' or 'recent' }
  local relative_time = format_relative_time(pr.updatedAt)
  if relative_time then
    table.insert(parts, 'updated ' .. relative_time)
  end
  if pr.author then
    table.insert(parts, '@' .. pr.author)
  end
  if pr.baseRefName and pr.headRefName then
    table.insert(parts, string.format('%s -> %s', pr.headRefName, pr.baseRefName))
  end

  return string.format('(%s)', table.concat(parts, ' | '))
end

local function normalize_remote_url(value)
  return vim
    .trim(value)
    :gsub('^git@([^:]+):', 'https://%1/')
    :gsub('^ssh://git@([^/]+)/', 'https://%1/')
    :gsub('^(https?://)[^/@]+@', '%1')
    :gsub('%.git$', '')
    :gsub('/+$', '')
    :lower()
end

local function sanitize_remote_name(value)
  local sanitized = value:gsub('[^%w%._%-]+', '-'):gsub('^-+', ''):gsub('-+$', '')
  if sanitized == '' then
    return 'gh-pr'
  end

  return sanitized
end

local function get_repository_url(value)
  local match = normalize_remote_url(value):match('^(https?://[^/]+/[^/]+/[^/]+)')
  return match
end

local function run_command(cwd, cmd, args)
  local command = { cmd }
  vim.list_extend(command, args or {})
  local result = vim.system(command, { cwd = cwd, text = true }):wait()

  return {
    stdout = result.stdout or '',
    stderr = result.stderr or '',
    exit_code = result.code or 1,
  }
end

local function jj(cwd, ...)
  local result = run_command(cwd, 'jj', { ... })
  return {
    stdout = result.stdout,
    stderr = result.stderr,
    ok = result.exit_code == 0,
  }
end

local function gh(cwd, ...)
  local result = run_command(cwd, 'gh', { ... })
  return {
    stdout = result.stdout,
    stderr = result.stderr,
    ok = result.exit_code == 0,
  }
end

local function is_jj_repo(cwd)
  return jj(cwd, 'root').ok
end

local function has_modified_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local bo = vim.bo[bufnr]
      if bo.modified and bo.buftype == '' then
        return true
      end
    end
  end

  return false
end

local function get_state_file_path()
  return vim.fs.joinpath(vim.fn.stdpath('state'), 'sidekick-review.json')
end

local function load_plugin_state()
  local state_path = get_state_file_path()
  if vim.fn.filereadable(state_path) == 0 then
    return { [CUSTOM_INSTRUCTIONS_KEY] = {} }
  end

  local ok, lines = pcall(vim.fn.readfile, state_path)
  if not ok then
    notify('Failed to read sidekick review state', vim.log.levels.WARN)
    return { [CUSTOM_INSTRUCTIONS_KEY] = {} }
  end

  local decoded = decode_json(table.concat(lines, '\n'))
  if type(decoded) ~= 'table' then
    notify('Ignoring invalid sidekick review state file', vim.log.levels.WARN)
    return { [CUSTOM_INSTRUCTIONS_KEY] = {} }
  end

  decoded[CUSTOM_INSTRUCTIONS_KEY] = type(decoded[CUSTOM_INSTRUCTIONS_KEY]) == 'table' and decoded[CUSTOM_INSTRUCTIONS_KEY] or {}
  return decoded
end

local function save_plugin_state(state)
  local state_path = get_state_file_path()
  local dir = vim.fs.dirname(state_path)
  vim.fn.mkdir(dir, 'p')

  local ok, encoded = pcall(vim.json.encode, state)
  if not ok then
    notify('Failed to encode sidekick review state', vim.log.levels.ERROR)
    return false
  end

  local write_ok, write_result = pcall(vim.fn.writefile, { encoded }, state_path)
  if not write_ok or write_result ~= 0 then
    notify('Failed to persist sidekick review state', vim.log.levels.ERROR)
    return false
  end

  return true
end

local function get_custom_instructions(cwd)
  local state = load_plugin_state()
  return normalize_custom_instructions(state[CUSTOM_INSTRUCTIONS_KEY][cwd])
end

local function set_custom_instructions(cwd, value)
  local state = load_plugin_state()
  local normalized = normalize_custom_instructions(value)

  if normalized then
    state[CUSTOM_INSTRUCTIONS_KEY][cwd] = normalized
  else
    state[CUSTOM_INSTRUCTIONS_KEY][cwd] = nil
  end

  save_plugin_state(state)
  return normalized
end

local function load_project_review_guidelines(cwd)
  local current_dir = vim.fs.normalize(cwd)

  while current_dir do
    local opencode_dir = vim.fs.joinpath(current_dir, '.opencode')
    local guidelines_path = vim.fs.joinpath(current_dir, 'REVIEW_GUIDELINES.md')

    local opencode_stats = vim.uv.fs_stat(opencode_dir)
    if opencode_stats and opencode_stats.type == 'directory' then
      local guideline_stats = vim.uv.fs_stat(guidelines_path)
      if not guideline_stats or guideline_stats.type ~= 'file' then
        return nil
      end

      local ok, lines = pcall(vim.fn.readfile, guidelines_path)
      if not ok then
        notify('Failed to read REVIEW_GUIDELINES.md', vim.log.levels.WARN)
        return nil
      end

      local trimmed = normalize_custom_instructions(table.concat(lines, '\n'))
      return trimmed
    end

    local parent_dir = vim.fs.dirname(current_dir)
    if not parent_dir or parent_dir == current_dir then
      return nil
    end
    current_dir = parent_dir
  end

  return nil
end

local function make_pick_item(label, value, description)
  local text = label
  if description then
    text = string.format('%s %s', label, description)
  end

  return {
    text = text,
    label = label,
    description = description,
    value = value,
  }
end

local function pick_one(title, items, callback)
  vim.ui.select(items, {
    prompt = title,
    format_item = function(item)
      return item.text
    end,
  }, callback)
end

local function input(prompt, default, callback)
  vim.ui.input({ prompt = prompt, default = default }, callback)
end

function M.open()
  local cwd = get_cwd()
  if not is_jj_repo(cwd) then
    notify('Sidekick review only works inside a jj repository', vim.log.levels.ERROR)
    return
  end

  local review_custom_instructions = get_custom_instructions(cwd)

  local function set_review_custom_instructions(value)
    review_custom_instructions = set_custom_instructions(cwd, value)
  end

  local function has_working_copy_changes()
    local result = jj(cwd, 'diff', '--summary')
    return result.ok and vim.trim(result.stdout) ~= ''
  end

  local function get_recent_changes(limit)
    local effective_limit = math.max(limit or 20, MIN_CHANGE_REVIEW_OPTIONS)
    local result = jj(
      cwd,
      'log',
      '-r',
      'all()',
      '-n',
      tostring(effective_limit),
      '--no-graph',
      '-T',
      'change_id.shortest(8) ++ "\\t" ++ description.first_line() ++ "\\n"'
    )
    if not result.ok then
      return {}
    end

    return parse_changes(result.stdout)
  end

  local function get_pull_requests(args, review_requested)
    local command = {
      'pr',
      'list',
    }
    vim.list_extend(command, args)
    vim.list_extend(command, {
      '--json',
      'number,title,updatedAt,author,baseRefName,headRefName',
    })

    local response = gh(cwd, list_unpack(command))
    if not response.ok then
      return {}
    end

    local pull_requests = parse_pull_requests(response.stdout)
    for _, pr in ipairs(pull_requests) do
      pr.reviewRequested = review_requested
    end

    return pull_requests
  end

  local function get_selectable_pull_requests()
    local updated_since = get_pull_request_updated_since_date(PULL_REQUEST_MAX_AGE_DAYS)
    local review_requested = get_pull_requests({
      '--search',
      string.format('review-requested:@me updated:>=%s sort:updated-desc', updated_since),
      '--limit',
      '50',
    }, true)
    local recent = get_pull_requests({
      '--search',
      string.format('updated:>=%s sort:updated-desc', updated_since),
      '--limit',
      tostring(RECENT_PULL_REQUEST_LIMIT),
    }, false)

    return dedupe_pull_requests(vim.list_extend(review_requested, recent))
  end

  local function parse_nonempty_lines(stdout)
    return split_nonempty_lines(stdout)
  end

  local function bookmark_refs_equal(left, right)
    return left.name == right.name and left.remote == right.remote
  end

  local function dedupe_bookmark_refs(bookmarks)
    local seen = {}
    local result = {}

    for _, bookmark in ipairs(bookmarks) do
      local key = string.format('%s@%s', bookmark.name, bookmark.remote or '')
      if not seen[key] then
        seen[key] = true
        table.insert(result, bookmark)
      end
    end

    return result
  end

  local function get_bookmark_refs(opts)
    opts = opts or {}
    local args = { 'bookmark', 'list' }
    if opts.includeRemotes then
      table.insert(args, '--all-remotes')
    end
    if opts.revset then
      vim.list_extend(args, { '-r', opts.revset })
    end
    vim.list_extend(args, { '-T', 'name ++ "\\t" ++ remote ++ "\\n"' })

    local result = jj(cwd, list_unpack(args))
    if not result.ok then
      return {}
    end

    return dedupe_bookmark_refs(parse_bookmarks(result.stdout))
  end

  local function get_single_revision_id(revset)
    local result = jj(cwd, 'log', '-r', revset, '--no-graph', '-T', 'commit_id ++ "\\n"')
    if not result.ok then
      return nil
    end

    local revisions = parse_nonempty_lines(result.stdout)
    if #revisions == 1 then
      return revisions[1]
    end

    return nil
  end

  local function get_single_change_id(revset)
    local result = jj(cwd, 'log', '-r', revset, '--no-graph', '-T', 'change_id.shortest(8) ++ "\\n"')
    if not result.ok then
      return nil
    end

    local revisions = parse_nonempty_lines(result.stdout)
    if #revisions == 1 then
      return revisions[1]
    end

    return nil
  end

  local function get_jj_remotes()
    local result = jj(cwd, 'git', 'remote', 'list')
    if not result.ok then
      return {}
    end

    local remotes = {}
    for _, line in ipairs(parse_nonempty_lines(result.stdout)) do
      local parts = vim.split(line, '%s+', { trimempty = true })
      local name = parts[1]
      table.remove(parts, 1)
      local url = table.concat(parts, ' ')
      if name and url ~= '' then
        table.insert(remotes, { name = name, url = url })
      end
    end

    return remotes
  end

  local function get_default_remote(remotes)
    for _, remote in ipairs(remotes) do
      if remote.name == 'origin' then
        return remote
      end
    end

    return remotes[1]
  end

  local function get_default_remote_name()
    local remote = get_default_remote(get_jj_remotes())
    return remote and remote.name or nil
  end

  local function prefer_bookmark_ref(bookmarks, preferred_remote)
    if #bookmarks == 0 then
      return nil
    end

    for _, bookmark in ipairs(bookmarks) do
      if not bookmark.remote then
        return bookmark
      end
    end

    if preferred_remote then
      for _, bookmark in ipairs(bookmarks) do
        if bookmark.remote == preferred_remote then
          return bookmark
        end
      end
    end

    return bookmarks[1]
  end

  local function resolve_bookmark_ref(bookmark, remote)
    if remote then
      return { name = bookmark, remote = remote }
    end

    for _, entry in ipairs(get_bookmark_refs()) do
      if entry.name == bookmark then
        return entry
      end
    end

    local matching_remote_bookmarks = {}
    for _, entry in ipairs(get_bookmark_refs({ includeRemotes = true })) do
      if entry.remote and entry.name == bookmark then
        table.insert(matching_remote_bookmarks, entry)
      end
    end

    if #matching_remote_bookmarks == 0 then
      return nil
    end

    return prefer_bookmark_ref(matching_remote_bookmarks, get_default_remote_name())
  end

  local function get_merge_base(bookmark, remote)
    local ref = resolve_bookmark_ref(bookmark, remote)
    if not ref then
      return nil
    end

    local result = jj(
      cwd,
      'log',
      '-r',
      string.format('heads(::@ & ::%s)', bookmark_revset(ref)),
      '--no-graph',
      '-T',
      'change_id.shortest(8) ++ "\\n"'
    )
    if not result.ok then
      return nil
    end

    local lines = parse_nonempty_lines(result.stdout)
    if #lines == 1 then
      return lines[1]
    end

    return nil
  end

  local function get_review_bookmarks()
    local local_bookmarks = get_bookmark_refs()
    local local_names = {}
    for _, bookmark in ipairs(local_bookmarks) do
      local_names[bookmark.name] = true
    end

    local default_remote_name = get_default_remote_name()
    local remote_only_bookmarks = {}
    for _, bookmark in ipairs(get_bookmark_refs({ includeRemotes = true })) do
      if bookmark.remote and not local_names[bookmark.name] then
        table.insert(remote_only_bookmarks, bookmark)
      end
    end

    table.sort(remote_only_bookmarks, function(left, right)
      if left.name ~= right.name then
        return left.name < right.name
      end
      if left.remote == default_remote_name then
        return true
      end
      if right.remote == default_remote_name then
        return false
      end
      return (left.remote or '') < (right.remote or '')
    end)

    return dedupe_bookmark_refs(vim.list_extend(local_bookmarks, remote_only_bookmarks))
  end

  local function get_review_head_revset()
    if has_working_copy_changes() then
      return '@'
    end

    return '@-'
  end

  local function get_current_review_bookmarks()
    return get_bookmark_refs({
      revset = get_review_head_revset(),
      includeRemotes = true,
    })
  end

  local function get_default_bookmark_ref()
    local default_remote_name = get_default_remote_name()
    local trunk_bookmarks = get_bookmark_refs({
      revset = 'trunk()',
      includeRemotes = true,
    })
    local trunk_bookmark = prefer_bookmark_ref(trunk_bookmarks, default_remote_name)
    if trunk_bookmark then
      return trunk_bookmark
    end

    local bookmarks = get_review_bookmarks()
    for _, bookmark in ipairs(bookmarks) do
      if not bookmark.remote and bookmark.name == 'main' then
        return bookmark
      end
    end
    for _, bookmark in ipairs(bookmarks) do
      if not bookmark.remote and bookmark.name == 'master' then
        return bookmark
      end
    end
    for _, bookmark in ipairs(bookmarks) do
      if bookmark.remote == default_remote_name and bookmark.name == 'main' then
        return bookmark
      end
    end
    for _, bookmark in ipairs(bookmarks) do
      if bookmark.remote == default_remote_name and bookmark.name == 'master' then
        return bookmark
      end
    end

    return bookmarks[1]
  end

  local function build_target_review_prompt(target, opts)
    local include_local_changes = opts and opts.includeLocalChanges == true or false

    if target.type == 'workingCopy' then
      return WORKING_COPY_PROMPT
    end

    if target.type == 'baseBookmark' then
      local bookmark = resolve_bookmark_ref(target.bookmark, target.remote)
      local bookmark_label_value = bookmark_label(bookmark or { name = target.bookmark, remote = target.remote })
      local merge_base = get_merge_base(target.bookmark, target.remote)
      local base_prompt
      if merge_base then
        base_prompt = BASE_BOOKMARK_PROMPT_WITH_MERGE_BASE
        base_prompt = replace_placeholder(base_prompt, '{baseBookmark}', bookmark_label_value)
        base_prompt = replace_placeholder(base_prompt, '{mergeBaseChangeId}', merge_base)
      else
        base_prompt = replace_placeholder(BASE_BOOKMARK_PROMPT_FALLBACK, '{bookmark}', bookmark_label_value)
      end

      if include_local_changes then
        return string.format('%s %s', base_prompt, LOCAL_CHANGES_REVIEW_INSTRUCTIONS)
      end

      return base_prompt
    end

    if target.type == 'change' then
      if target.title then
        local prompt = replace_placeholder(CHANGE_PROMPT_WITH_TITLE, '{changeId}', target.changeId)
        return replace_placeholder(prompt, '{title}', target.title)
      end

      return replace_placeholder(CHANGE_PROMPT, '{changeId}', target.changeId)
    end

    if target.type == 'pullRequest' then
      local bookmark = resolve_bookmark_ref(target.baseBookmark, target.baseRemote)
      local base_bookmark_label = bookmark_label(bookmark or {
        name = target.baseBookmark,
        remote = target.baseRemote,
      })
      local merge_base = get_merge_base(target.baseBookmark, target.baseRemote)
      local base_prompt
      if merge_base then
        base_prompt = PULL_REQUEST_PROMPT
        base_prompt = replace_placeholder(base_prompt, '{prNumber}', tostring(target.prNumber))
        base_prompt = replace_placeholder(base_prompt, '{title}', target.title)
        base_prompt = replace_placeholder(base_prompt, '{baseBookmark}', base_bookmark_label)
        base_prompt = replace_placeholder(base_prompt, '{mergeBaseChangeId}', merge_base)
      else
        base_prompt = PULL_REQUEST_PROMPT_FALLBACK
        base_prompt = replace_placeholder(base_prompt, '{prNumber}', tostring(target.prNumber))
        base_prompt = replace_placeholder(base_prompt, '{title}', target.title)
        base_prompt = replace_placeholder(base_prompt, '{baseBookmark}', base_bookmark_label)
      end

      if include_local_changes then
        return string.format('%s %s', base_prompt, LOCAL_CHANGES_REVIEW_INSTRUCTIONS)
      end

      return base_prompt
    end

    return replace_placeholder(FOLDER_REVIEW_PROMPT, '{paths}', table.concat(target.paths, ', '))
  end

  local function build_review_prompt(target)
    local prompt = build_target_review_prompt(target, {
      includeLocalChanges = target.type ~= 'workingCopy' and has_working_copy_changes(),
    })
    local project_guidelines = load_project_review_guidelines(cwd)
    local full_prompt = string.format('%s\n\n---\n\nPlease perform a code review with the following focus:\n\n%s', REVIEW_RUBRIC, prompt)

    if review_custom_instructions then
      full_prompt = string.format(
        '%s\n\nCustom review instructions for this working directory (applies to all review modes here):\n\n%s',
        full_prompt,
        review_custom_instructions
      )
    end

    if project_guidelines then
      full_prompt = string.format(
        '%s\n\nThis project has additional instructions for code reviews:\n\n%s',
        full_prompt,
        project_guidelines
      )
    end

    return full_prompt
  end

  local function get_smart_default()
    if has_working_copy_changes() then
      return 'workingCopy'
    end

    local default_bookmark = get_default_bookmark_ref()
    if default_bookmark then
      local review_head_revision = get_single_revision_id(get_review_head_revset())
      local default_bookmark_revision = get_single_revision_id(bookmark_revset(default_bookmark))
      if review_head_revision and default_bookmark_revision and review_head_revision ~= default_bookmark_revision then
        return 'baseBookmark'
      end
    end

    return 'change'
  end

  local function start_review(target, opts)
    opts = opts or {}
    local prompt = build_review_prompt(target)
    local ok, err = pcall(function()
      local Session = require('sidekick.cli.session')
      local State = require('sidekick.cli.state')

      local session = Session.new({
        tool = 'opencode',
        cwd = cwd,
        id = string.format('sidekick-review:%d', vim.uv.hrtime()),
        backend = 'terminal',
      })

      session = Session.attach(session)

      local state = State.get_state(session)
      if state.terminal then
        state.terminal:show()
        state.terminal:focus()
      end

      session:send(prompt .. '\n')

      local attempts = 0

      local function submit_when_ready()
        attempts = attempts + 1

        local states = State.get({
          name = 'opencode',
          external = true,
          started = true,
          cwd = true,
        })

        if states[1] and states[1].session then
          states[1].session:submit()
        elseif attempts < 100 then
          vim.defer_fn(submit_when_ready, 50)
        else
          session:submit()
        end
      end

      vim.defer_fn(submit_when_ready, 100)
    end)

    if not ok then
      local err = err
      notify('Failed to start review prompt automatically: ' .. tostring(err), vim.log.levels.ERROR)
      if opts.onError then
        opts.onError(err)
      end
    end
  end

  local function materialize_pr(pr_number)
    if has_modified_buffers() then
      return {
        ok = false,
        error = 'You have unsaved Neovim buffers. Save or discard them first.',
      }
    end

    if has_working_copy_changes() then
      return {
        ok = false,
        error = 'You have local jj changes. Snapshot or discard them first.',
      }
    end

    local saved_change_id = get_single_change_id('@')
    if not saved_change_id then
      return { ok = false, error = 'Failed to determine the current change' }
    end

    local pr_response = gh(
      cwd,
      'pr',
      'view',
      tostring(pr_number),
      '--json',
      'baseRefName,title,headRefName,isCrossRepository,headRepository,headRepositoryOwner,url'
    )
    if not pr_response.ok then
      return {
        ok = false,
        error = string.format('Could not find PR #%d. Check gh auth and that the PR exists.', pr_number),
      }
    end

    local pr_info = decode_json(pr_response.stdout)
    if type(pr_info) ~= 'table' then
      return { ok = false, error = 'Failed to parse PR info' }
    end

    local remotes = get_jj_remotes()
    local default_remote = get_default_remote(remotes)
    if not default_remote then
      return { ok = false, error = 'No jj remotes configured' }
    end

    local base_repo_url = get_repository_url(pr_info.url or '')
    local base_remote
    if base_repo_url then
      for _, remote in ipairs(remotes) do
        if get_repository_url(remote.url) == base_repo_url then
          base_remote = remote
          break
        end
      end
    end

    local remote_name = default_remote.name
    local added_temp_remote = false

    if pr_info.isCrossRepository then
      local fork_url = pr_info.headRepository and pr_info.headRepository.url or nil
      local fork_repo_url = fork_url and get_repository_url(fork_url) or nil
      local existing_remote
      if fork_repo_url then
        for _, remote in ipairs(remotes) do
          if get_repository_url(remote.url) == fork_repo_url then
            existing_remote = remote
            break
          end
        end
      end

      if existing_remote then
        remote_name = existing_remote.name
      elseif fork_url then
        local base_name = sanitize_remote_name(string.format(
          'gh-pr-%s-%s',
          pr_info.headRepositoryOwner and pr_info.headRepositoryOwner.login or 'remote',
          pr_info.headRepository and pr_info.headRepository.name or tostring(pr_number)
        ))
        local used_names = {}
        for _, remote in ipairs(remotes) do
          used_names[remote.name] = true
        end

        remote_name = base_name
        local suffix = 2
        while used_names[remote_name] do
          remote_name = string.format('%s-%d', base_name, suffix)
          suffix = suffix + 1
        end

        local add_remote_result = jj(cwd, 'git', 'remote', 'add', remote_name, fork_url)
        if not add_remote_result.ok then
          return { ok = false, error = 'Failed to add PR remote' }
        end
        added_temp_remote = true
      else
        return { ok = false, error = 'PR fork URL is unavailable' }
      end
    end

    local fetch_head_result = jj(cwd, 'git', 'fetch', '--remote', remote_name, '--branch', pr_info.headRefName)
    if not fetch_head_result.ok then
      if added_temp_remote then
        jj(cwd, 'git', 'remote', 'remove', remote_name)
      end
      return { ok = false, error = 'Failed to fetch PR branch' }
    end

    local revset = string.format(
      'remote_bookmarks(exact:%s, exact:%s)',
      vim.json.encode(pr_info.headRefName),
      vim.json.encode(remote_name)
    )
    local create_change_result = jj(cwd, 'new', revset)
    if not create_change_result.ok then
      if added_temp_remote then
        jj(cwd, 'git', 'remote', 'remove', remote_name)
      end
      return { ok = false, error = 'Failed to create change on PR branch' }
    end

    if added_temp_remote then
      jj(cwd, 'git', 'remote', 'remove', remote_name)
    end

    return {
      ok = true,
      title = pr_info.title,
      baseBookmark = pr_info.baseRefName,
      baseRemote = base_remote and base_remote.name or nil,
      headBookmark = pr_info.headRefName,
      remote = remote_name,
      savedChangeId = saved_change_id,
    }
  end

  local show_review_selector
  local show_bookmark_selector
  local show_change_selector
  local show_pr_selector
  local show_pr_manual_input
  local show_custom_instructions_input
  local show_folder_input
  local handle_pr_review

  function show_custom_instructions_input()
    input('Custom review instructions: ', review_custom_instructions or '', function(value)
      if value == nil then
        show_review_selector()
        return
      end

      local next = normalize_custom_instructions(value)
      if not next then
        notify('Custom review instructions not changed', vim.log.levels.INFO)
        show_review_selector()
        return
      end

      set_review_custom_instructions(next)
      notify('Custom review instructions saved for this directory', vim.log.levels.INFO)
      show_review_selector()
    end)
  end

  function show_bookmark_selector()
    local bookmarks = get_review_bookmarks()
    local current_bookmarks = get_current_review_bookmarks()
    local default_bookmark = get_default_bookmark_ref()
    local candidates = {}

    for _, bookmark in ipairs(bookmarks) do
      local duplicate = false
      for _, current_bookmark in ipairs(current_bookmarks) do
        if bookmark_refs_equal(bookmark, current_bookmark) then
          duplicate = true
          break
        end
      end
      if not duplicate then
        table.insert(candidates, bookmark)
      end
    end

    if #candidates == 0 then
      local current_label = current_bookmarks[1] and bookmark_label(current_bookmarks[1]) or nil
      if current_label then
        notify('No other bookmarks found (current bookmark: ' .. current_label .. ')', vim.log.levels.ERROR)
      else
        notify('No bookmarks found', vim.log.levels.ERROR)
      end
      return
    end

    table.sort(candidates, function(a, b)
      if default_bookmark and bookmark_refs_equal(a, default_bookmark) then
        return true
      end
      if default_bookmark and bookmark_refs_equal(b, default_bookmark) then
        return false
      end
      if (a.remote ~= nil) ~= (b.remote ~= nil) then
        return a.remote == nil
      end
      return bookmark_label(a) < bookmark_label(b)
    end)

    local items = {}
    for _, bookmark in ipairs(candidates) do
      local description
      if default_bookmark and bookmark_refs_equal(bookmark, default_bookmark) then
        description = '(default)'
      elseif bookmark.remote then
        description = '(remote ' .. bookmark.remote .. ')'
      end
      table.insert(items, make_pick_item(bookmark_label(bookmark), bookmark, description))
    end

    pick_one('Select base bookmark', items, function(choice)
      if not choice then
        return
      end

      start_review({
        type = 'baseBookmark',
        bookmark = choice.value.name,
        remote = choice.value.remote,
      })
    end)
  end

  function show_change_selector()
    local changes = get_recent_changes()
    if #changes == 0 then
      notify('No changes found', vim.log.levels.ERROR)
      return
    end

    local items = {}
    for _, change in ipairs(changes) do
      table.insert(items, make_pick_item(string.format('%s  %s', change.changeId, change.title), change))
    end

    pick_one('Select change to review', items, function(choice)
      if not choice then
        return
      end

      start_review({
        type = 'change',
        changeId = choice.value.changeId,
        title = choice.value.title,
      })
    end)
  end

  function show_pr_manual_input()
    input('Enter PR number or URL: ', '', function(value)
      if value == nil then
        show_pr_selector()
        return
      end

      local pr_number = parse_pr_ref(value)
      if not pr_number then
        notify('Invalid PR reference. Enter a number or GitHub PR URL.', vim.log.levels.ERROR)
        show_pr_manual_input()
        return
      end

      handle_pr_review(pr_number)
    end)
  end

  function show_pr_selector()
    if has_modified_buffers() then
      notify('Cannot materialize PR: you have unsaved Neovim buffers. Save or discard them first.', vim.log.levels.ERROR)
      return
    end

    if has_working_copy_changes() then
      notify('Cannot materialize PR: you have local jj changes. Please snapshot or discard them first.', vim.log.levels.ERROR)
      return
    end

    local pull_requests = get_selectable_pull_requests()
    local items = {
      make_pick_item('Enter a PR number or URL', {
        prNumber = -1,
        title = 'Manual entry',
        updatedAt = '',
        reviewRequested = false,
        isManualEntry = true,
      }, '(override the list)'),
    }

    for _, pr in ipairs(pull_requests) do
      table.insert(items, make_pick_item(string.format('#%d  %s', pr.prNumber, pr.title), pr, build_pull_request_option_description(pr)))
    end

    pick_one('Select pull request to review', items, function(choice)
      if not choice then
        return
      end

      if choice.value.isManualEntry then
        show_pr_manual_input()
        return
      end

      handle_pr_review(choice.value.prNumber)
    end)
  end

  function handle_pr_review(pr_number)
    local result = materialize_pr(pr_number)
    if not result.ok then
      notify(result.error, vim.log.levels.ERROR)
      return
    end

    start_review({
      type = 'pullRequest',
      prNumber = pr_number,
      baseBookmark = result.baseBookmark,
      baseRemote = result.baseRemote,
      title = result.title,
    }, {
      onError = function()
        local restored = jj(cwd, 'edit', result.savedChangeId)
        if restored.ok then
          notify('Restored the previous change after the review prompt failed', vim.log.levels.INFO)
          return
        end

        notify(
          string.format('Review prompt failed and restoring the previous change also failed (%s)', result.savedChangeId),
          vim.log.levels.ERROR
        )
      end,
    })
  end

  function show_folder_input()
    input('Enter folders/files to review: ', '.', function(value)
      if value == nil then
        return
      end

      local paths = {}
      for _, part in ipairs(vim.split(value, '%s+', { trimempty = true })) do
        local path = vim.trim(part)
        if path ~= '' then
          table.insert(paths, path)
        end
      end

      if #paths == 0 then
        notify('No paths provided', vim.log.levels.ERROR)
        show_folder_input()
        return
      end

      start_review({ type = 'folder', paths = paths })
    end)
  end

  function show_review_selector()
    local smart_default = get_smart_default()
    local items = {
      make_pick_item(
        smart_default == 'workingCopy' and 'Review working-copy changes (default)' or 'Review working-copy changes',
        'workingCopy'
      ),
      make_pick_item(
        smart_default == 'baseBookmark' and 'Review against a base bookmark (default)' or 'Review against a base bookmark',
        'baseBookmark',
        '(local)'
      ),
      make_pick_item(smart_default == 'change' and 'Review a change (default)' or 'Review a change', 'change'),
      make_pick_item('Review a pull request', 'pullRequest', '(GitHub PR)'),
      make_pick_item('Review a folder (or more)', 'folder', '(snapshot, not diff)'),
      make_pick_item(
        review_custom_instructions and 'Remove custom review instructions' or 'Add custom review instructions',
        'toggleCustomInstructions',
        review_custom_instructions and '(set for this directory)' or '(this directory, all review modes)'
      ),
    }

    pick_one('Select a review preset', items, function(choice)
      if not choice then
        return
      end

      if choice.value == 'workingCopy' then
        start_review({ type = 'workingCopy' })
        return
      end
      if choice.value == 'baseBookmark' then
        show_bookmark_selector()
        return
      end
      if choice.value == 'change' then
        show_change_selector()
        return
      end
      if choice.value == 'pullRequest' then
        show_pr_selector()
        return
      end
      if choice.value == 'folder' then
        show_folder_input()
        return
      end

      if review_custom_instructions then
        set_review_custom_instructions(nil)
        notify('Custom review instructions removed for this directory', vim.log.levels.INFO)
        show_review_selector()
        return
      end

      show_custom_instructions_input()
    end)
  end

  show_review_selector()
end

function M.setup()
  vim.api.nvim_create_user_command('SidekickReview', function()
    M.open()
  end, {
    desc = 'Review code changes with Sidekick',
  })
end

return M
