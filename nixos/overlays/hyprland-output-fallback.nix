final: prev:

{
  hyprland = prev.hyprland.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ../patches/hyprland-last-monitor-fallback-workspaces.patch
    ];
  });
}
