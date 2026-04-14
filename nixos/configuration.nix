{ lib, pkgs, host, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ./desktop.nix
    ./security.nix
    ./programs.nix
    ./home
    ./auto-upgrade.nix
    ./nordvpn.nix
  ];

  # --- Networking ---
  networking.hostName = host.hostname;
  networking.networkmanager.enable = true;
  # Writable DNS backend so VPN clients (NordVPN) and NetworkManager can push
  # resolvers via D-Bus -- /etc/resolv.conf is read-only on NixOS.
  services.resolved.enable = true;

  # --- Nix settings ---
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    cores = 0;           # 0 = use all available cores for each build
    max-jobs = "auto";   # Run as many build jobs in parallel as there are cores
    auto-optimise-store = true;   # Deduplicate nix store paths at build time via hardlinks
    substituters = lib.mkIf host.nvidia [ "https://cache.nixos-cuda.org" ];
    trusted-public-keys = lib.mkIf host.nvidia [ "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" ];
  };
  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.overlays = [ (import ./overlays/cli-tools.nix) ];
  nixpkgs.config.allowUnfree = true;

  # --- Locale ---
  time.timeZone = host.timezone;

  i18n.defaultLocale = host.defaultLocale;
  i18n.extraLocaleSettings = {
    LC_ADDRESS = host.regionalLocale;
    LC_IDENTIFICATION = host.regionalLocale;
    LC_MEASUREMENT = host.regionalLocale;   # Metric
    LC_MONETARY = host.regionalLocale;      # Euro
    LC_NAME = host.defaultLocale;
    LC_NUMERIC = host.defaultLocale;
    LC_PAPER = host.regionalLocale;         # A4
    LC_TELEPHONE = host.regionalLocale;
    LC_TIME = host.regionalLocale;          # 24h, DD/MM/YYYY
  };

  # --- Shell ---
  programs.zsh.enable = true;

  # --- User ---
  users.users.${host.username} = {
    isNormalUser = true;
    description = host.username;
    extraGroups = [ "networkmanager" "wheel" "video" "audio" "gamemode" "nordvpn" ];
    shell = pkgs.zsh;
  };

  system.stateVersion = "25.11";
}
