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
    lanzaboote = { url = "github:nix-community/lanzaboote/v1.0.0"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = { nixpkgs, home-manager, agenix, lanzaboote, ... }:
    let
      _host = import ./host.nix;
      host = _host // { homeDir = "/home/${_host.username}"; };

      # Shared across NixOS system and standalone packages output (avoids duplication)
      cliToolsOverlay = import ./overlays/cli-tools.nix;

      requiredFields = [ "username" "hostname" "timezone" "defaultLocale" "regionalLocale"
                         "tmpfsSize" "steamScaling" "cursorSize" "nvidia" "repoDir" "autoUpgrade" ];
      missingFields = builtins.filter (f: ! builtins.hasAttr f _host) requiredFields;
    in
    assert missingFields == []
      || builtins.throw "host.nix is missing required fields: ${builtins.toJSON missingFields}";
  {
    nixosConfigurations.${host.hostname} = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit agenix host; };
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
      inherit (pkgs) claude-code gemini-cli opencode codex;
    };
  };
}
