#!/usr/bin/env bash
set -euo pipefail

print_info() {
	printf '\033[34m[INFO]\033[0m %s\n' "$1"
}

print_success() {
	printf '\033[32m[OK]\033[0m %s\n' "$1"
}

print_error() {
	printf '\033[31m[ERROR]\033[0m %s\n' "$1" >&2
}

print_warning() {
	printf '\033[33m[WARN]\033[0m %s\n' "$1"
}

get_hostname() {
	if [[ "$(uname -s)" == "Darwin" ]]; then
		scutil --get LocalHostName 2>/dev/null || hostname -s
	else
		hostname
	fi
}

resolve_host() {
	if [[ $# -eq 0 || -z "${1:-}" ]]; then
		get_hostname
	else
		printf '%s\n' "$1"
	fi
}

cleanup_result_link() {
	if [[ -e ./result || -L ./result ]]; then
		rm ./result
	fi
}

build_config() {
	local kind="$1"
	local hostname="${2:-}"
	shift
	if [[ $# -gt 0 ]]; then
		shift
	fi

	local host
	host="$(resolve_host "$hostname")"

	print_info "Building configuration for ${host}"

	if [[ "$kind" == "darwin" ]]; then
		nix build ".#darwinConfigurations.${host}.system" --show-trace "$@"
	else
		nix build ".#nixosConfigurations.${host}.config.system.build.toplevel" --show-trace "$@"
	fi

	cleanup_result_link
	print_success "Build completed successfully"
}

update_flake() {
	if [[ $# -eq 0 ]]; then
		print_info "Updating all flake inputs"
		nix flake update
	else
		print_info "Updating flake inputs: $*"
		nix flake update "$@"
	fi

	print_info "Regenerating flake.nix"
	nix run .#write-flake

	print_info "Formatting"
	alejandra .

	print_success "Flake updated"
}
