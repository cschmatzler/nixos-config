#!/usr/bin/env nu

export def print_info [msg: string] {
    print $"(ansi blue)[INFO](ansi reset) ($msg)"
}

export def print_success [msg: string] {
    print $"(ansi green)[OK](ansi reset) ($msg)"
}

export def print_error [msg: string] {
    print $"(ansi red)[ERROR](ansi reset) ($msg)"
}

export def print_warning [msg: string] {
    print $"(ansi yellow)[WARN](ansi reset) ($msg)"
}

export def get-hostname [] {
	if $nu.os-info.name == "macos" {
		try { ^scutil --get LocalHostName | str trim } catch { ^hostname -s | str trim }
	} else {
		^hostname | str trim
	}
}

export def resolve-host [hostname?: string] {
	if ($hostname | is-empty) {
		get-hostname
	} else {
		$hostname
	}
}

export def cleanup-result-link [] {
	if ("./result" | path exists) {
		rm ./result
	}
}

export def build-config [kind: string, hostname?: string, ...rest: string] {
	let host = resolve-host $hostname

	print_info $"Building configuration for ($host)"

	if $kind == "darwin" {
		nix build $".#darwinConfigurations.($host).system" --show-trace ...$rest
	} else {
		nix build $".#nixosConfigurations.($host).config.system.build.toplevel" --show-trace ...$rest
	}

	cleanup-result-link
	print_success "Build completed successfully"
}

export def update-flake [inputs: list<string>] {
	if ($inputs | is-empty) {
		print_info "Updating all flake inputs"
		nix flake update
	} else {
		print_info $"Updating flake inputs: ($inputs | str join ', ')"
		nix flake update ...$inputs
	}

	print_info "Regenerating flake.nix"
	nix run .#write-flake

	print_info "Formatting"
	alejandra .

	print_success "Flake updated"
}
