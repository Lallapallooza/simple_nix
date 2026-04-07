{ lib, host, ... }:

{
  # Desktop entry for glow (terminal markdown viewer) so file managers can open .md files
  xdg.desktopEntries.glow = {
    name = "Glow";
    exec = "kitty --title Glow glow -p %f";
    terminal = false;
    mimeType = [ "text/markdown" "text/x-markdown" ];
  };

  # Override imv desktop entry -- upstream ships NoDisplay=true which hides it
  # from Dolphin's "Open With" dialog, making it impossible to select
  xdg.desktopEntries.imv = {
    name = "imv";
    exec = "imv %F";
    terminal = false;
    icon = "multimedia-photo-viewer";
    categories = [ "Graphics" "2DGraphics" "Viewer" ];
    mimeType = [
      "image/png" "image/jpeg" "image/gif" "image/bmp" "image/webp"
      "image/svg+xml" "image/tiff" "image/avif" "image/heif" "image/jxl"
    ];
  };

  # --- Dotfile deployments (edit in repo, then nixos-rebuild switch) ---
  xdg.configFile."mc/ini".source = ../../config/mc/ini;
  xdg.configFile."mc/bat-viewer.sh" = { source = ../../config/mc/bat-viewer.sh; executable = true; };

  # Discord Flatpak -- force XWayland on NVIDIA (GBM can't init inside Flatpak sandbox)
  # TODO: remove when NVIDIA GBM works inside Flatpak sandbox
  home.file.".local/share/flatpak/overrides/com.discordapp.Discord" = lib.mkIf host.nvidia {
    text = ''
      [Environment]
      ELECTRON_OZONE_PLATFORM_HINT=x11
    '';
  };
  home.file.".var/app/com.discordapp.Discord/config/discord-flags.conf" = lib.mkIf host.nvidia {
    text = ''
      --ignore-gpu-blocklist
      --ozone-platform=x11
    '';
  };
}
