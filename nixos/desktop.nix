{ pkgs, host, ... }:

{
  # --- Display Manager ---
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.defaultSession = "hyprland-uwsm";
  # Plasma as fallback DE, system settings, AND Qt theming (Breeze) for Hyprland.
  # Removing Plasma breaks: Qt theme (theming.nix kde/breeze), Dolphin "Open With"
  # (hyprland-applications.menu below), and QT_QPA_PLATFORMTHEME=kde in user.conf.
  services.desktopManager.plasma6.enable = true;

  # Hyprland (tiling Wayland compositor)
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;   # Run X11 apps under Wayland
  };

  # XDG portals -- required for screen sharing, file dialogs, and secrets in Wayland
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config = {
      common.default = [ "*" ];
      hyprland = {
        default = [ "hyprland" "gtk" ];
        "org.freedesktop.impl.portal.OpenURI" = [ "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
    };
  };

  # Dolphin needs the Plasma menu definition to discover apps for "Open With".
  # plasma-workspace ships plasma-applications.menu but doesn't link it into /etc/xdg/menus/.
  # UWSM sets XDG_MENU_PREFIX=hyprland- in the systemd user session, so Dolphin looks for
  # hyprland-applications.menu. We symlink both names so it works in any session.
  environment.etc."xdg/menus/plasma-applications.menu".source =
    "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
  environment.etc."xdg/menus/hyprland-applications.menu".source =
    "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  # Polkit -- needed for GUI privilege escalation (e.g. mounting drives)
  security.polkit.enable = true;

  # dconf -- required for GTK apps to persist their settings
  programs.dconf.enable = true;

  # --- Environment ---
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";             # Force Electron apps to use native Wayland
    XDG_MENU_PREFIX = "plasma-";      # Plasma sessions / TTY; Hyprland session overridden to hyprland- by UWSM
    TERMINAL = "kitty";
    EDITOR = "nvim";
    VISUAL = "nvim";
    VIEWER = "${host.homeDir}/.config/mc/bat-viewer.sh";
    __GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";   # Don't prune shader cache -- reduces stutter in games
    RTK_TELEMETRY_DISABLED = "1";     # Disable RTK telemetry
  };

  environment.shellAliases = {
    vim = "nvim";
    vi = "nvim";
  };

  # Keyboard: US + Russian layouts, toggle with Super+Space
  # NOTE: keep in sync with config/hypr/user.conf input section
  services.xserver.xkb = {
    layout = "us,ru";
    variant = "";
    options = "grp:win_space_toggle";
  };

  # --- Audio (PipeWire) ---
  services.pulseaudio.enable = false;   # Disabled in favor of PipeWire
  security.rtkit.enable = true;         # Realtime scheduling for audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;           # 32-bit ALSA support (games)
    pulse.enable = true;                # PulseAudio compatibility
    jack.enable = true;                 # JACK compatibility (pro audio apps)
  };

  # Nerd Fonts -- required for terminal/neovim icons and powerline glyphs
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    inter                       # Modern UI font with excellent Cyrillic support
    paratype-pt-sans            # Cyrillic
    noto-fonts-cjk-sans         # Japanese, Chinese, Korean
    noto-fonts-color-emoji      # Color emoji
  ];

  # Prefer in browser/app fallback chains
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Inter" "PT Sans" "Noto Sans" ];
    serif = [ "Noto Serif" ];
    monospace = [ "JetBrainsMono Nerd Font" "Fira Code" ];
  };
}
