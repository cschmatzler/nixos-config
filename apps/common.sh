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
  local kind

  kind="$(platform_kind)" || return
  case "$kind" in
    darwin)
      scutil --get LocalHostName 2>/dev/null || hostname -s || return
      ;;
    nixos)
      hostname || return
      ;;
    *)
      print_error "Unsupported platform kind while resolving the local Host: $kind"
      return 1
      ;;
  esac
}

resolve_host() {
  local host

  if [[ -z "${1:-}" ]]; then
    host="$(get_hostname)" || return
  else
    host="$1"
  fi

  require_host_kind "$host" >/dev/null || return
  printf '%s\n' "$host"
}

load_host_manifest() {
  if ! declare -F host_kind >/dev/null; then
    if [[ -z "${HOST_MANIFEST:-}" ]]; then
      print_error "HOST_MANIFEST must point to the generated Host manifest"
      return 1
    fi

    # shellcheck source=/dev/null
    source "$HOST_MANIFEST" || return
  fi
}

require_host_kind() {
  local host
  local kind

  host="$1"
  load_host_manifest || return
  kind="$(host_kind "$host")" || {
    print_error "Unknown Host: $host"
    return 1
  }

  case "$kind" in
    darwin | nixos) printf '%s\n' "$kind" ;;
    *)
      print_error "Unsupported Host kind for $host: $kind"
      return 1
      ;;
  esac
}

platform_kind() {
  local kernel
  local os_id

  kernel="$(uname -s)" || return
  case "$kernel" in
    Darwin)
      printf '%s\n' darwin
      ;;
    Linux)
      if [[ ! -r /etc/os-release ]]; then
        print_error "Unsupported platform: Linux without readable /etc/os-release; use Darwin or NixOS"
        return 1
      fi

      os_id="$(
        unset ID || exit 1
        # shellcheck source=/etc/os-release
        source /etc/os-release || exit 1
        printf '%s\n' "${ID:-}"
      )" || return

      if [[ "$os_id" != "nixos" ]]; then
        print_error "Unsupported platform: Linux distribution ${os_id:-unknown}; use Darwin or NixOS"
        return 1
      fi

      printf '%s\n' nixos
      ;;
    *)
      print_error "Unsupported platform: $kernel; use Darwin or NixOS"
      return 1
      ;;
  esac
}

require_local_host_kind() {
  local host
  local detected_host
  local kind
  local current_platform

  host="$1"
  detected_host="$(get_hostname)" || return
  if [[ "$host" != "$detected_host" ]]; then
    print_error "Host $host is not the current Host $detected_host"
    return 1
  fi

  kind="$(require_host_kind "$host")" || return
  current_platform="$(platform_kind)" || return

  if [[ "$kind" != "$current_platform" ]]; then
    print_error "Host $host is declared as $kind but the current platform is $current_platform"
    return 1
  fi

  printf '%s\n' "$kind"
}

resolve_local_host() {
  local host

  host="$(get_hostname)" || return
  require_local_host_kind "$host" >/dev/null || return
  printf '%s\n' "$host"
}

build_host() {
  local host
  local kind

  host="$1"
  shift
  kind="$(require_host_kind "$host")" || return
  case "$kind" in
    darwin)
      nix build ".#darwinConfigurations.${host}.system" --show-trace "$@" || return
      ;;
    nixos)
      nix build ".#nixosConfigurations.${host}.config.system.build.toplevel" --show-trace "$@" || return
      ;;
    *)
      print_error "Unsupported Host kind for build: $kind"
      return 1
      ;;
  esac
}

apply_local_host() {
  local host
  local kind

  host="$1"
  shift
  kind="$(require_local_host_kind "$host")" || return
  case "$kind" in
    darwin)
      run_as_root darwin-rebuild switch --flake ".#${host}" "$@" || return
      ;;
    nixos)
      run_as_root nixos-rebuild switch --flake ".#${host}" "$@" || return
      ;;
    *)
      print_error "Unsupported Host kind for apply: $kind"
      return 1
      ;;
  esac
}

rollback_local_host() {
  local host
  local generation
  local kind

  host="$1"
  generation="$2"
  kind="$(require_local_host_kind "$host")" || return
  case "$kind" in
    darwin)
      run_as_root darwin-rebuild switch --switch-generation "$generation" || return
      ;;
    nixos)
      run_as_root nix-env \
        --profile /nix/var/nix/profiles/system \
        --switch-generation "$generation" || return
      run_as_root /nix/var/nix/profiles/system/bin/switch-to-configuration switch || return
      ;;
    *)
      print_error "Unsupported Host kind for rollback: $kind"
      return 1
      ;;
  esac
}

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@" || return
  else
    sudo "$@" || return
  fi
}
