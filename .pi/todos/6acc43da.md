{
  "id": "6acc43da",
  "title": "Implement fast Herdr microVM startup and reusable templates",
  "tags": [
    "herdr",
    "microvm",
    "performance",
    "security"
  ],
  "status": "blocked",
  "created_at": "2026-08-12T06:57:49.316Z",
  "assigned_to_session": "019ff1db-576b-710e-bcb8-34badff50884"
}

Implemented accepted architecture:
- warm pane <=500 ms p95 target via ControlMaster, runtime incarnation state, inline validated pane environment, and a true warm fast path
- restored compatibility-keyed devenv/Aube node_modules reuse using stable /home/agent/workspace, exact v2 compatibility fingerprints, v3 fingerprints, SQLite snapshots, bounded archive validation, transactional guest import, and canonical Aube/devenv validation
- implemented fresh-workspace-only credential-free sparse raw disk template publish/consume with root-controlled candidacy/attachment markers, guest sanitize verification, Docker clearing, runner-derived template keys, clone manifest verification, pending clone recovery, space/freshness/quota GC, and fail-closed removal
- retained guest-kernel, scoped broker, credential, egress, Git publication, resource, and private state boundaries
Adversarial review loops fixed all critical/high findings identified in the warm/cache/template paths. Remaining limitation: runtime and performance targets require user activation; per AGENTS.md no build/apply was run.
Validation passed:
- npm typecheck and bundle
- fish syntax
- Alejandra
- git diff --check
- Tahani toplevel evaluation
- nix flake check --no-build
No commit/push. No linked project worktree was modified by implementation commands.
Blocked on user activation and end-to-end measurements before completion.
