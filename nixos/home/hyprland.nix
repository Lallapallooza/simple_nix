{ ... }:

{
  # Hyprland -- HM generates hyprland.conf which just sources the user config
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;   # UWSM handles session management when enabled
    package = null;            # NixOS module provides the package, avoid conflict
    portalPackage = null;      # System-level xdg.portal handles portals, avoid path override
    plugins = [];
    extraConfig = ''
      source = ~/.config/hypr/user.conf
    '';
  };
}
