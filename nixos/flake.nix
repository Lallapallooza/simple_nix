{
  description = "NixOS system configuration";

  inputs = {
    # unstable for latest kernel + nvidia
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # user/dotfile management
    home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };

    # secret management (age-encrypted secrets in git)
    agenix = { url = "github:ryantm/agenix"; inputs.nixpkgs.follows = "nixpkgs"; };

    # secure boot signing for systemd-boot
    lanzaboote = { url = "github:nix-community/lanzaboote/v1.1.0"; inputs.nixpkgs.follows = "nixpkgs"; };

    # Go TUI viewer for the Beads issue tracker (Dicklesworthstone fork).
    # br (Rust port) is built from source in overlays/cli-tools.nix instead.
    beads_viewer = { url = "github:Dicklesworthstone/beads_viewer"; inputs.nixpkgs.follows = "nixpkgs"; };

    # Nightly Rust toolchain. Needed by br: transitive dep `fsqlite-types`
    # uses `#![feature(portable_simd)]` which is nightly-only.
    fenix = { url = "github:nix-community/fenix"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = { nixpkgs, home-manager, agenix, lanzaboote, beads_viewer, fenix, ... }:
    let
      _host = import ./host.nix;
      host = _host // { homeDir = "/home/${_host.username}"; };

      # Shared across NixOS system and standalone packages output (avoids duplication)
      cliToolsOverlay = import ./overlays/cli-tools.nix { inherit fenix; };

      requiredFields = [ "username" "hostname" "timezone" "defaultLocale" "regionalLocale"
                         "tmpfsSize" "steamScaling" "cursorSize" "nvidia" "repoDir" "autoUpgrade" ];
      missingFields = builtins.filter (f: ! builtins.hasAttr f _host) requiredFields;
    in
    assert missingFields == []
      || builtins.throw "host.nix is missing required fields: ${builtins.toJSON missingFields}";
  {
    nixosConfigurations.${host.hostname} = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit agenix host cliToolsOverlay;
        bv = beads_viewer.packages.x86_64-linux.bv;
      };
      modules = [
        home-manager.nixosModules.home-manager
        agenix.nixosModules.default
        lanzaboote.nixosModules.lanzaboote
        ./configuration.nix
      ];
    };

    # Expose overlaid CLI tools for lightweight hash computation in CI.
    # `nix build ./nixos#claude-code` builds just that package (no NixOS config eval).
    # Separate nixpkgs instantiation is intentional -- avoids full NixOS config eval in CI.
    packages.x86_64-linux = let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
        overlays = [ cliToolsOverlay ];
      };
    in {
      inherit (pkgs) claude-code opencode codex br;
    };
  };
}
