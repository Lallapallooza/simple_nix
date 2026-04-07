{ host, ... }:

{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "bak";
  home-manager.extraSpecialArgs = { inherit host; };
  home-manager.users.${host.username} = {
    imports = [
      ./shell.nix
      ./theming.nix
      ./apps.nix
      ./hyprland.nix
    ];

    home.stateVersion = "25.11";
    home.sessionPath = [ "${host.homeDir}/.local/bin" ];
  };
}
