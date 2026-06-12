# Overlay for AI coding CLI tools.
# Versions and hashes are grouped at the top for easy programmatic updates.
# When the overlay version matches nixpkgs, the upstream package is used as-is.
{ fenix }:
final: prev:

let
  # -- claude-code (prebuilt native binary from Anthropic GCS) ---------
  # 2.1.113+ ships a Bun-compiled single-file binary (no cli.js). We fetch
  # the per-platform binary directly and wrap it; buildNpmPackage is bypassed.
  claudeCodeVersion = "2.1.181";
  claudeCodeNativeHashes = {
    x86_64-linux   = "sha256-Nf/U6dmoY5XQuk4F+LI78Ji/6rlel96s1lN5CdEyTpw=";
    aarch64-linux  = "sha256-E5P5k1M+CNXJYkVQR1Cn/P43SQpfRO7DWwvqw9cJ2rk=";
    x86_64-darwin  = "sha256-NTeYvNxJpSpmZkU3DhxIqE/oN9k7+dlUwZM43KcmDd0=";
    aarch64-darwin = "sha256-xNgzsEYGzvm26rOtJV7S4USPh96ivAD/Ws93tX326U0=";
  };
  claudeCodeNativePlatform = {
    x86_64-linux   = "linux-x64";
    aarch64-linux  = "linux-arm64";
    x86_64-darwin  = "darwin-x64";
    aarch64-darwin = "darwin-arm64";
  };
  claudeCodeGcsBase = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";

  # -- opencode (stdenvNoCC + Bun, GitHub source) ----------------------
  opencodeVersion = "1.17.8";
  opencodeSrcHash = "sha256-iReCFIJeJIOIs95v0ReVR/X1PnT5dSnR9O0TniyvPR8=";
  opencodeNodeModulesHash = "sha256-ERywlcNEF9EUW3JDGH8987g+GAj76RylUtegqMvStyg=";

  # -- br / beads_rust (buildRustPackage, GitHub source) ---------------
  # Upstream's flake.nix is broken (crane vendors Cargo.lock at the wrong
  # path) and pulls a sibling toon_rust input. We sidestep that by building
  # the published tarball directly: the released Cargo.toml depends on
  # `tru` from crates.io, not a path dep, so no source-tree gymnastics.
  # Nightly is required because the transitive crate `fsqlite-types` opts
  # into #![feature(portable_simd)]. Pinned to upstream's rust-toolchain.toml.
  brVersion = "0.2.11";
  brSrcHash = "sha256-XfxO1gDt51CWv6T/wEX97uLm89Px0rEmCZEcofeWZG0=";
  brCargoHash = "sha256-3u7GMriV2ZG0mjjGYLXGcUDQrs83uRYDMy5NKXTdaTI=";
  brNightlyDate = "2026-02-19";
  brNightlySha = "sha256-ccIyMJknpRkaU9pLkFC4E9j0XxMa50GT4CYhwGvs8/U=";

  # -- codex (buildRustPackage, GitHub source) -------------------------
  codexVersion = "0.141.0";
  codexSrcHash = "sha256-1ZOaZlwAkH6DJpxlInfbXpaqmsbOIOGrFoj2dYehBMA=";
  codexCargoHash = "sha256-bQPeRKTrNYeGCO20hpu+F37sScFOGr1EPOVf1E0FU+4=";
  codexLibrustyV8Version = "149.2.0";
  codexLibrustyV8Hashes = {
    x86_64-linux = "sha256-iu2YY323533Iv7i7R1nsW95HLQv3lD9Y4OYqNQlFxVk=";
    aarch64-linux = "sha256-+XdRJ8pk3MSjZi0BpSGizvuluY+DOUOog9hHc7Kv88U=";
    x86_64-darwin = "sha256-eUlAo4o/ZrfvUqXwA8awlPdDrQQKZK+z082frUlADwc=";
    aarch64-darwin = "sha256-+rsuyNO6Wm3qY9uaNalg3FypheujLzQrm6Sqocc0sv4=";
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

  # -- br --------------------------------------------------------------
  br = let
    fenixPkgs = fenix.packages.${prev.stdenv.hostPlatform.system};
    nightly = fenixPkgs.toolchainOf {
      channel = "nightly";
      date = brNightlyDate;
      sha256 = brNightlySha;
    };
    rustToolchain = fenixPkgs.combine [
      nightly.cargo
      nightly.rustc
      nightly.rust-src
    ];
    rustPlatform = prev.makeRustPlatform {
      cargo = rustToolchain;
      rustc = rustToolchain;
    };
  in rustPlatform.buildRustPackage {
    pname = "br";
    version = brVersion;

    src = prev.fetchFromGitHub {
      owner = "Dicklesworthstone";
      repo = "beads_rust";
      tag = "v${brVersion}";
      hash = brSrcHash;
    };

    cargoHash = brCargoHash;

    nativeBuildInputs = [ prev.pkg-config ];
    buildInputs = [ prev.openssl prev.sqlite ];

    env.OPENSSL_NO_VENDOR = "1";

    doCheck = false;

    meta = {
      description = "Agent-first issue tracker (SQLite + JSONL). Rust port of beads.";
      homepage = "https://github.com/Dicklesworthstone/beads_rust";
      license = prev.lib.licenses.mit;
      mainProgram = "br";
      platforms = prev.lib.platforms.unix;
    };
  };

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
      # nixpkgs' inherited postPatch assumes older Cargo.toml content
      # (`lto = "fat"`). 0.139.0 uses `lto = "thin"`; the env overrides
      # below handle release profile settings without patching sources.
      postPatch = "";
      env = old.env // {
        RUSTY_V8_ARCHIVE = prev.fetchurl {
          name = "librusty_v8-${codexLibrustyV8Version}";
          url = "https://github.com/denoland/rusty_v8/releases/download/v${codexLibrustyV8Version}/librusty_v8_release_${prev.stdenv.hostPlatform.rust.rustcTarget}.a.gz";
          sha256 = codexLibrustyV8Hashes.${prev.stdenv.hostPlatform.system} or (builtins.throw "codex overlay: unsupported platform ${prev.stdenv.hostPlatform.system}");
        };
        CARGO_PROFILE_RELEASE_LTO = "false";
        CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
      };
    })
    else prev.codex or (builtins.throw "overlay: codex not found in nixpkgs");
}
