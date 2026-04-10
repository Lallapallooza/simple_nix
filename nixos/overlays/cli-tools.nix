# Overlay for AI coding CLI tools.
# Versions and hashes are grouped at the top for easy programmatic updates.
# When the overlay version matches nixpkgs, the upstream package is used as-is.
final: prev:

let
  # -- claude-code (buildNpmPackage, npm tarball) ----------------------
  claudeCodeVersion = "2.1.100";
  claudeCodeSrcHash = "sha256-7/Rhk1z3Us2vOYGa85lkVIzzqdQFmfmAxrT39a7D27Y=";
  claudeCodeNpmDepsHash = "sha256-izy3dQProZIdUF5Z11fvGQOm/TBcWGhDK8GvNs8gG5E=";

  # -- gemini-cli (buildNpmPackage, GitHub source) ---------------------
  geminiCliVersion = "0.37.1";
  geminiCliSrcHash = "sha256-1InZ8lJ1RgE4PbKR77rtJvGNQq6A1HDC+1nARfsVacs=";
  geminiCliNpmDepsHash = "sha256-Fj+kLCOJNLH/gQRlBN3QdCCgG4Q49o6Gq6VUmg8p/lY=";

  # -- opencode (stdenvNoCC + Bun, GitHub source) ----------------------
  opencodeVersion = "1.4.3";
  opencodeSrcHash = "sha256-m+Ue7FWiTjKMAn1QefAwOMfOb2Vybk0mJPV9zcbkOmE=";
  opencodeNodeModulesHash = "sha256-hVXlQcUuvUudIB35Td6ucBYopM/QOSx59tQbCTqoB/0=";

  # -- codex (buildRustPackage, GitHub source) -------------------------
  codexVersion = "0.118.0";
  codexSrcHash = "sha256-FdtV+CIqTInnegcXrXBxw4aE0JnNDh4GdYKwUDjSk9Y=";
  codexCargoHash = "sha256-l+3k7j2Qtmw8uUnzLGK9pNJIK0O6fuTpB+XaiP/TWuE=";
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
      cargoDeps = old.cargoDeps.overrideAttrs {
        name = "codex-${version}-vendor";
        inherit src sourceRoot;
        outputHash = codexCargoHash;
        outputHashMode = "recursive";
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
