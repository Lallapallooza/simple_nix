{ ... }:

{
  # Hyprland -- HM generates hyprland.conf which just sources the user config
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";   # extraConfig below is hyprlang; pin it so the 26.05 default flip to lua does not reinterpret it
    systemd.enable = false;   # UWSM handles session management when enabled
    package = null;            # NixOS module provides the package, avoid conflict
    portalPackage = null;      # System-level xdg.portal handles portals, avoid path override
    plugins = [];
    extraConfig = ''
      source = ~/.config/hypr/user.conf
    '';
  };
}
