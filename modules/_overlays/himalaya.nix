{inputs, ...}: final: prev: let
	inherit (final) lib stdenv;
	features = [];
	withFeatures = features;
	withNoDefaultFeatures = false;
	hasPgpGpgFeature = builtins.elem "pgp-gpg" features;
	hasKeyringFeature = builtins.elem "keyring" features;
	hasNotmuchFeature = builtins.elem "notmuch" features;
	emulator = stdenv.hostPlatform.emulator final.buildPackages;
	exe = stdenv.hostPlatform.extensions.executable;
	dbus' =
		final.dbus.overrideAttrs (old: {
				env =
					(old.env or {})
					// {
						NIX_CFLAGS_COMPILE =
							(old.env.NIX_CFLAGS_COMPILE or "")
							+ lib.optionalString (stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isAarch64) " -mno-outline-atomics";
					};
			});
in {
	himalaya =
		final.rustPlatform.buildRustPackage {
			pname = "himalaya";
			version = "2.0.0-alpha.1";

			src = inputs.himalaya;
			cargoHash = "sha256-wYzkxOwdBg9e+026tylGgpLnaEhEbylESlr6N/FA6KA=";

			inherit withFeatures withNoDefaultFeatures;

			env.OPENSSL_NO_VENDOR = "1";

			nativeBuildInputs =
				[]
				++ lib.optional (hasPgpGpgFeature || hasKeyringFeature || hasNotmuchFeature) final.pkg-config
				++ lib.optional (stdenv.buildPlatform.canExecute stdenv.hostPlatform) final.installShellFiles;

			buildInputs =
				[]
				++ lib.optional hasPgpGpgFeature final.gpgme
				++ lib.optional (hasKeyringFeature && !stdenv.hostPlatform.isWindows) dbus'
				++ lib.optional hasNotmuchFeature final.notmuch;

			doCheck = false;

			postInstall =
				lib.optionalString (lib.hasInfix "wine" emulator) ''
					export WINEPREFIX="''${WINEPREFIX:-$(mktemp -d)}"
					mkdir -p $WINEPREFIX
				''
				+ ''
					mkdir -p $out/share/{applications,completions,man}
					cp assets/himalaya.desktop "$out"/share/applications/
					${emulator} "$out"/bin/himalaya${exe} manual "$out"/share/man
					${emulator} "$out"/bin/himalaya${exe} completion bash > "$out"/share/completions/himalaya.bash
					${emulator} "$out"/bin/himalaya${exe} completion elvish > "$out"/share/completions/himalaya.elvish
					${emulator} "$out"/bin/himalaya${exe} completion fish > "$out"/share/completions/himalaya.fish
					${emulator} "$out"/bin/himalaya${exe} completion powershell > "$out"/share/completions/himalaya.powershell
					${emulator} "$out"/bin/himalaya${exe} completion zsh > "$out"/share/completions/himalaya.zsh
				''
				+ lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
					installManPage "$out"/share/man/*
					installShellCompletion "$out"/share/completions/himalaya.{bash,fish,zsh}
				'';

			meta = {
				description = "CLI to manage emails";
				mainProgram = "himalaya";
				homepage = "https://github.com/pimalaya/himalaya";
				changelog = "https://github.com/pimalaya/himalaya/blob/v2.0.0-alpha.1/CHANGELOG.md";
				license = lib.licenses.mit;
				maintainers = with lib.maintainers; [
					soywod
					yanganto
				];
			};
		};
}
