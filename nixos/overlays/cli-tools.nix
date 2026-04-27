# Overlay for AI coding CLI tools.
# Versions and hashes are grouped at the top for easy programmatic updates.
# When the overlay version matches nixpkgs, the upstream package is used as-is.
final: prev:

let
  # -- claude-code (prebuilt native binary from Anthropic GCS) ---------
  # 2.1.113+ ships a Bun-compiled single-file binary (no cli.js). We fetch
  # the per-platform binary directly and wrap it; buildNpmPackage is bypassed.
  claudeCodeVersion = "2.1.119";
  claudeCodeNativeHashes = {
    x86_64-linux   = "sha256-zKQwU/BilJSVWWsRtv0bWc95ECrbE7rL5mmX5vrkHko=";
    aarch64-linux  = "sha256-OCqnPqSwf9jWmOMVm1754bhzn651BbqN3Si4pqYoGc4=";
    x86_64-darwin  = "sha256-UrO3XP6AxiaYKy/7Omzhx5eCTyV9wnXPCjwywgK2o98=";
    aarch64-darwin = "sha256-Mds0RDCdXQ+Lheh4Li3NhvMffkjBoeg9abCSaMe0+aI=";
  };
  claudeCodeNativePlatform = {
    x86_64-linux   = "linux-x64";
    aarch64-linux  = "linux-arm64";
    x86_64-darwin  = "darwin-x64";
    aarch64-darwin = "darwin-arm64";
  };
  claudeCodeGcsBase = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";

  # -- gemini-cli (buildNpmPackage, GitHub source) ---------------------
  geminiCliVersion = "0.39.1";
  geminiCliSrcHash = "sha256-O0TBrT3WDCBZ3ZyFyJPBBtPfnDzdFQ7b8pOJOD7bj2g=";
  geminiCliNpmDepsHash = "sha256-y0LafX1+ukW8HRYBqQ3QfZGHo1cVk00bNygdwsBR/7g=";

  # -- opencode (stdenvNoCC + Bun, GitHub source) ----------------------
  opencodeVersion = "1.14.26";
  opencodeSrcHash = "sha256-Wuwv7XGDlLBOuX3Oq06Cvk8F86nm2A7R7zVN80ZUzf0=";
  opencodeNodeModulesHash = "sha256-+mh57Oz5pTqKZZjIKAtFvUJZXqxyyrDk7iO/ccZValI=";

  # -- codex (buildRustPackage, GitHub source) -------------------------
  codexVersion = "0.125.0";
  codexSrcHash = "sha256-q175gmBw+edb5+w8TM36yUeFsyIdB1/IwWzbxBbBmoA=";
  codexCargoHash = "sha256-fDVlj7zAZnwP9YBaYaSQZXYYWrBm5IEyLT9zoorvzFg=";
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
  # When our pinned version is newer than nixpkgs', build a fresh derivation
  # from Anthropic's prebuilt native binary. The old nixpkgs derivation is
  # buildNpmPackage with a postPatch on cli.js which no longer exists in 2.1.113+.
  claude-code =
    if prev ? claude-code && versionNewer claudeCodeVersion prev.claude-code.version
    then
      let
        system = prev.stdenv.hostPlatform.system;
        platform = claudeCodeNativePlatform.${system}
          or (builtins.throw "claude-code overlay: unsupported platform ${system}");
        nativeBinary = prev.fetchurl {
          url = "${claudeCodeGcsBase}/${claudeCodeVersion}/${platform}/claude";
          hash = claudeCodeNativeHashes.${system};
        };
      in prev.stdenv.mkDerivation {
        pname = "claude-code";
        version = claudeCodeVersion;

        dontUnpack = true;
        # The "native" binary is a Bun single-file executable with a trailer;
        # stripping corrupts it.
        dontStrip = true;

        nativeBuildInputs = [ prev.makeBinaryWrapper ]
          ++ prev.lib.optionals prev.stdenv.hostPlatform.isElf [ prev.autoPatchelfHook ];

        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          install -m755 ${nativeBinary} $out/bin/.claude-unwrapped
          makeBinaryWrapper $out/bin/.claude-unwrapped $out/bin/claude \
            --set DISABLE_AUTOUPDATER 1 \
            --set DISABLE_INSTALLATION_CHECKS 1 \
            --set USE_BUILTIN_RIPGREP 0 \
            --prefix PATH : ${prev.lib.makeBinPath (
              [ prev.procps prev.ripgrep ]
              ++ prev.lib.optionals prev.stdenv.hostPlatform.isLinux [ prev.bubblewrap prev.socat ]
            )}
          runHook postInstall
        '';

        meta = (prev.claude-code.meta or {}) // {
          mainProgram = "claude";
        };
      }
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
        # prettier is a root-workspace devDep; --filter . is needed so bun install includes it
        buildPhase = ''
          runHook preBuild

          bun install \
            --cpu="*" \
            --frozen-lockfile \
            --filter ./packages/app \
            --filter ./packages/desktop \
            --filter ./packages/opencode \
            --filter . \
            --ignore-scripts \
            --no-progress \
            --os="*"

          bun --bun ./nix/scripts/canonicalize-node-modules.ts
          bun --bun ./nix/scripts/normalize-bun-binaries.ts

          runHook postBuild
        '';
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
