#!/usr/bin/env nu

const repo = "tuist/tuist"

def fail [msg: string] {
	error make {msg: $msg}
}

def clean [s: string] {
	$s | str replace --all "\t" " " | str replace --all "\n" " "
}

def pick-pr [] {
	let prs = (
		gh pr list --repo $repo --state open --limit 200 --json number,title,headRefName,author
		| from json
	)

	if ($prs | is-empty) {
		fail $"No open PRs found for ($repo)"
	}

	let choice = (
		$prs
		| each {|pr|
			let title = (clean $pr.title)
			let branch = (clean $pr.headRefName)
			let author = $pr.author.login
			$"($pr.number)\t($title)\t($author)\t($branch)"
		}
		| str join (char newline)
		| fzf --prompt "tuist pr > " --delimiter "\t" --with-nth "1,2,3,4" --preview "gh pr view --repo tuist/tuist {1}" --preview-window "right:70%"
	)

	if ($choice | str trim | is-empty) {
		exit 130
	}

	$choice | split row "\t" | first | into int
}

def main [pr_number?: int] {
	let number = if ($pr_number | is-empty) { pick-pr } else { $pr_number }
	let pr = (
		gh pr view --repo $repo $number --json number,title,url
		| from json
	)

	let base = ([$env.HOME "Projects" "Work"] | path join)
	let dest = ([$base $"tuist-pr-($pr.number)"] | path join)

	if ($dest | path exists) {
		fail $"Destination already exists: ($dest)"
	}

	^mkdir -p $base

	print $"Cloning ($repo) PR #($pr.number): ($pr.title)"
	jj git clone $"https://github.com/($repo).git" $dest

	do {
		cd $dest
		gh pr checkout $pr.number
	}

	print $"Ready: ($dest)"
}
