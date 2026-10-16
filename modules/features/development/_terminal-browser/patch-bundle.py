"""Apply Nix policy only to the pinned, extracted terminal-browser release."""

import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
release = json.loads(sys.argv[2])
shell = sys.argv[3]
policy = Path(sys.argv[4]).read_text()
paths = release["paths"]
if (root / "VERSION").read_text().strip() != release["tag"]:
    raise SystemExit("archive VERSION differs from the pinned release")

identity_patch = (
    'var APP_DIR_NAME = `terminal-browser${INSTALL_ROOT.dev ? "-dev" : ""}-${suffix}`;',
    f'var APP_DIR_NAME = {json.dumps(release["stateIdentity"])};',
)
herdr_patch = (
    r'''      async function prepare() {
        try {
          const configPath = herdrConfigPath(env);
          const current = node_fs_1.default.existsSync(configPath) ? node_fs_1.default.readFileSync(configPath, "utf8") : "";
          if (/^[ \t]*kitty_graphics[ \t]*=[ \t]*true[ \t]*$/m.test(current))
            return;
          node_fs_1.default.mkdirSync(node_path_1.default.dirname(configPath), { recursive: true });
          node_fs_1.default.writeFileSync(configPath, enableKittyGraphics(current));
          await herdr2(["server", "reload-config"]);
        } catch {
        }
      }''',
    r'''      async function prepare() {
        const configPath = herdrConfigPath(env);
        const current = node_fs_1.default.existsSync(configPath) ? node_fs_1.default.readFileSync(configPath, "utf8") : "";
        if (!/^[ \t]*kitty_graphics[ \t]*=[ \t]*true[ \t]*$/m.test(current))
          throw new Error("Herdr kitty_graphics must be enabled declaratively.");
      }''',
)
cli_patches = [
    identity_patch,
    herdr_patch,
    ('  if (command !== "setup") ensureSetup();\n', ""),
    (
        '  if (command === "setup") return setupCommand(electronBinary());',
        '  if (command === "setup") fail("Setup is managed by Nix; do not run the mutable upstream setup.");',
    ),
    (
        '  if (command === "upgrade") return upgradeCommand2();',
        '  if (command === "upgrade") fail("Upgrade the pinned Nix package instead of running the upstream installer.");',
    ),
    (
        '''    let sandboxError = linuxSandboxError(electron);
    if (sandboxError) {
      apparmorSetup(electron);
      sandboxError = linuxSandboxError(electron);
    }
    if (sandboxError) fail(sandboxError);''',
        '''    const sandboxError = linuxSandboxError(electron);
    if (sandboxError) fail(sandboxError);''',
    ),
    (
        "Run: terminal-browser setup",
        "This Nix installation requires a declarative host AppArmor policy",
    ),
    (
        'return { command: ["/bin/sh", "-c", line], cwd: browserDir };',
        f'return {{ command: [{json.dumps(shell)}, "-c", line], cwd: browserDir }};',
    ),
]
browser_patches = [
    identity_patch,
    herdr_patch,
    (
        '''  checkForUpdate() {
    if (this.release.version === "dev" || this.settings.get("updates.check") === "off") return;
    fetchLatestRelease(installedChannel(), AbortSignal.timeout(5e3)).then((latest) => {
      if (latest.version === this.release.version) return;
      this.release.latest = latest.version;
      this.render();
    }).catch(() => {
    });
  }''',
        '''  checkForUpdate() {
  }''',
    ),
]

patched = {}
for relative, replacements in [
    (paths["cli"], cli_patches),
    (paths["browser"], browser_patches),
]:
    file = root / relative
    text = file.read_text()
    for before, after in replacements:
        count = text.count(before)
        if count != 1:
            raise SystemExit(f"{relative}: expected one patch site, got {count}: {before!r}")
        text = text.replace(before, after)
    patched[file] = text

skill = root / paths["skill"] / "SKILL.md"
text = skill.read_text()
frontmatter = text.split("---\n", 2)
if len(frontmatter) != 3 or frontmatter[0] != "":
    raise SystemExit("the pinned skill's frontmatter shape changed")
patched[skill] = "---\n" + frontmatter[1] + "---\n\n" + policy.strip() + "\n" + frontmatter[2]

# Validate every patch before changing any file, including on a repeated run.
for file, text in patched.items():
    file.write_text(text)
