# Machine-specific settings -- edit this file when setting up a new PC
{
  username = "vitalii";
  # homeDir is derived as /home/${username} in flake.nix
  hostname = "nixos";
  timezone = "Europe/Dublin";
  defaultLocale = "en_US.UTF-8";
  regionalLocale = "en_IE.UTF-8";    # metric, euro, A4, 24h clock
  tmpfsSize = "16G";                 # ~half of RAM for build tmpfs
  steamScaling = "1.666667";         # HiDPI scaling for Steam (match monitor scale)
  cursorSize = 24;                   # cursor size (scale with DPI: 16@1x, 24@1.5x, 32@2x)
  nvidia = true;                     # set false on AMD/Intel GPU machines
  repoDir = "/home/vitalii/code/simple_nix";   # local clone path (for auto-upgrade) -- must match username above
  autoUpgrade = true;                # nightly rebuild from local clone (git pull + nixos-rebuild)
}
