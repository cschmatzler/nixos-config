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
  if [[ -z "${1:-}" ]]; then
    get_hostname
  else
    printf '%s\n' "$1"
  fi
}

load_host_manifest() {
  if ! declare -F host_kind >/dev/null; then
    : "${HOST_MANIFEST:?HOST_MANIFEST must point to the generated Host manifest}"
    # shellcheck source=/dev/null
    source "$HOST_MANIFEST"
  fi
}

require_host_kind() {
  local host="$1"
  local kind

  load_host_manifest
  if ! kind="$(host_kind "$host")"; then
    print_error "Unknown Host: $host"
    return 1
  fi

  printf '%s\n' "$kind"
}

platform_kind() {
  case "$(uname -s)" in
    Darwin) printf '%s\n' darwin ;;
    Linux) printf '%s\n' nixos ;;
    *)
      print_error "Unsupported platform: $(uname -s)"
      return 1
      ;;
  esac
}

resolve_local_host() {
  local host
  local kind
  local current_platform

  host="$(get_hostname)"
  kind="$(require_host_kind "$host")"
  current_platform="$(platform_kind)"

  if [[ "$kind" != "$current_platform" ]]; then
    print_error "Host $host is declared as $kind but the current platform is $current_platform"
    return 1
  fi

  printf '%s\t%s\n' "$host" "$kind"
}

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}
