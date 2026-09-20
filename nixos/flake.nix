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

  };

  outputs = { nixpkgs, home-manager, agenix, lanzaboote, ... }:
    let
      _host = import ./host.nix;
      host = _host // { homeDir = "/home/${_host.username}"; };

      requiredFields = [ "username" "hostname" "timezone" "defaultLocale" "regionalLocale"
                         "tmpfsSize" "steamScaling" "cursorSize" "nvidia" "repoDir" "updateCheck" ];
      missingFields = builtins.filter (f: ! builtins.hasAttr f _host) requiredFields;
    in
    assert missingFields == []
      || builtins.throw "host.nix is missing required fields: ${builtins.toJSON missingFields}";
  {
    nixosConfigurations.${host.hostname} = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit agenix host;
      };
      modules = [
        home-manager.nixosModules.home-manager
        agenix.nixosModules.default
        lanzaboote.nixosModules.lanzaboote
        ./configuration.nix
      ];
    };
  };
}
