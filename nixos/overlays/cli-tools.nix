# Overlay for AI coding CLI tools.
# Versions and hashes are grouped at the top for easy programmatic updates.
# When the overlay version matches nixpkgs, the upstream package is used as-is.
final: prev:

let
  # -- claude-code (buildNpmPackage, npm tarball) ----------------------
  claudeCodeVersion = "2.1.109";
  claudeCodeSrcHash = "sha256-tzqFLTe8lh2Qxs0Uo1L/QAVR7uYhRNU1ekErHNUSdsA=";
  claudeCodeNpmDepsHash = "sha256-izy3dQProZIdUF5Z11fvGQOm/TBcWGhDK8GvNs8gG5E=";

  # -- gemini-cli (buildNpmPackage, GitHub source) ---------------------
  geminiCliVersion = "0.38.0";
  geminiCliSrcHash = "sha256-DnjqTpF5aGY5HgUZyo00VpO3LHMSg0N1kDwmJaA0pjY=";
  geminiCliNpmDepsHash = "sha256-aHduayoVW6d3u7+PaUYQgZlAM4meUQ5CdfO/wxvLgy0=";

  # -- opencode (stdenvNoCC + Bun, GitHub source) ----------------------
  opencodeVersion = "1.4.6";
  opencodeSrcHash = "sha256-rVbWlVY4ujNVaE1o3SJmD0NrfWDtAfH+8MhOzmGgnhM=";
  opencodeNodeModulesHash = "sha256-0vIkCiVnyy3FwXWI3ZooskJGMhEI75BP9Xc/ZLWaTbk=";

  # -- codex (buildRustPackage, GitHub source) -------------------------
  codexVersion = "0.120.0";
  codexSrcHash = "sha256-kj8WWFNk0/ZIefA7xgDox8zvW3y4tyLT2lyi1SyeHz8=";
  codexCargoHash = "sha256-VY97UmTju9p+0rjdHXPaIq7JWTebZCrFzzrxyIjxaOg=";
  codexLibrustyV8Version = "146.4.0";
  codexLibrustyV8Hashes = {
    x86_64-linux = "sha256-5ktNmeSuKTouhGJEqJuAF4uhA4LBP7WRwfppaPUpEVM=";
    aarch64-linux = "sha256-2/FlsHyBvbBUvARrQ9I+afz3vMGkwbW0d2mDpxBi7Ng=";
    x86_64-darwin = "sha256-YwzSQPG77NsHFBfcGDh6uBz2fFScHFFaC0/Pnrpke7c=";
    aarch64-darwin = "sha256-v+LJvjKlbChUbw+WWCXuaPv2BkBfMQzE4XtEilaM+Yo=";
  };

  # Compare versions: true if a > b (by sort -V)
  versionNewer = a: b: a != b && builtins.compareVersions a b > 0;

in {

  # -- claude-code -----------------------------------------------------
  claude-code =
    if prev ? claude-code && versionNewer claudeCodeVersion prev.claude-code.version
    then prev.claude-code.overrideAttrs (old: rec {
      version = claudeCodeVersion;
      src = prev.fetchzip {
        url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
        hash = claudeCodeSrcHash;
      };
      npmDeps = prev.fetchNpmDeps {
        inherit src;
        inherit (old) postPatch;
        name = "claude-code-${version}-npm-deps";
        hash = claudeCodeNpmDepsHash;
      };
    })
    else prev.claude-code or (builtins.throw "overlay: claude-code not found in nixpkgs");

  # -- gemini-cli ------------------------------------------------------
  gemini-cli =
    if prev ? gemini-cli && versionNewer geminiCliVersion prev.gemini-cli.version
    then prev.gemini-cli.overrideAttrs (old: rec {
      version = geminiCliVersion;
      src = prev.fetchFromGitHub {
        owner = "google-gemini";
        repo = "gemini-cli";
        tag = "v${version}";
        hash = geminiCliSrcHash;
      };
      npmDeps = prev.fetchNpmDeps {
        inherit src;
        inherit (old) postPatch;
        name = "gemini-cli-${version}-npm-deps";
        hash = geminiCliNpmDepsHash;
      };
    })
    else prev.gemini-cli or (builtins.throw "overlay: gemini-cli not found in nixpkgs");

  # -- opencode --------------------------------------------------------
  opencode =
    if prev ? opencode && versionNewer opencodeVersion prev.opencode.version
    then prev.opencode.overrideAttrs (old: rec {
      version = opencodeVersion;
      src = prev.fetchFromGitHub {
        owner = "anomalyco";
        repo = "opencode";
        tag = "v${version}";
        hash = opencodeSrcHash;
      };
      node_modules = old.node_modules.overrideAttrs {
        inherit src;
        outputHash = opencodeNodeModulesHash;
      };
      env = old.env // {
        OPENCODE_VERSION = version;
      };
    })
    else prev.opencode or (builtins.throw "overlay: opencode not found in nixpkgs");

  # -- codex -----------------------------------------------------------
  codex =
    if prev ? codex && versionNewer codexVersion prev.codex.version
    then prev.codex.overrideAttrs (old: rec {
      version = codexVersion;
      src = prev.fetchFromGitHub {
        owner = "openai";
        repo = "codex";
        tag = "rust-v${version}";
        hash = codexSrcHash;
      };
      sourceRoot = "${src.name}/codex-rs";
      # Fresh build, not override: overrideAttrs doesn't reach nested vendorStaging -> stale Cargo.lock.
      cargoDeps = prev.rustPlatform.fetchCargoVendor {
        inherit src sourceRoot;
        name = "codex-${version}-vendor";
        hash = codexCargoHash;
      };
      env = old.env // {
        RUSTY_V8_ARCHIVE = prev.fetchurl {
          name = "librusty_v8-${codexLibrustyV8Version}";
          url = "https://github.com/denoland/rusty_v8/releases/download/v${codexLibrustyV8Version}/librusty_v8_release_${prev.stdenv.hostPlatform.rust.rustcTarget}.a.gz";
          sha256 = codexLibrustyV8Hashes.${prev.stdenv.hostPlatform.system} or (builtins.throw "codex overlay: unsupported platform ${prev.stdenv.hostPlatform.system}");
        };
      };
    })
    else prev.codex or (builtins.throw "overlay: codex not found in nixpkgs");
}
