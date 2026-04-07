{ pkgs, host, ... }:

{
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = host.cursorSize;
  };

  # --- GTK Theming (Adwaita-dark -- neutral, works with any accent) ---
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    gtk4.theme = null;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # --- Qt Theming (uses Plasma 6 Breeze Dark -- already installed as fallback DE) ---
  qt = {
    enable = true;
    platformTheme.name = "kde";
    style.name = "breeze";
  };

  # --- Dark mode for libadwaita / GNOME apps ---
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
      icon-theme = "Papirus-Dark";
    };
  };

  # GTK accent overrides (Ayu Dark)
  xdg.configFile."gtk-3.0/gtk.css".source = ../../config/gtk-3.0/gtk.css;
  xdg.configFile."gtk-4.0/gtk.css".source = ../../config/gtk-4.0/gtk.css;

  # KDE color scheme (Ayu Dark)
  xdg.configFile."kdeglobals".source = ../../config/kde/kdeglobals;
}
