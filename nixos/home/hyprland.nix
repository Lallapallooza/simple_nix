{ ... }:

{
  # Hyprland -- HM generates hyprland.lua which just loads the user config
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";        # hyprlang/.conf support is dropped in Hyprland 0.57
    systemd.enable = false;   # UWSM handles session management when enabled
    package = null;            # NixOS module provides the package, avoid conflict
    portalPackage = null;      # System-level xdg.portal handles portals, avoid path override
    plugins = [];
    extraConfig = ''
      dofile((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/user.lua")
    '';
  };
}
