# Overlay: two source patches applied via postPatch. ags.bundle re-runs the
# bundler during the build, so both land in bin/.hyprpanel-wrapped.
#
# 1. Notification body tooltip.
#    HyprPanel hardcodes lines=2 + maxWidthChars=35 + truncate on the
#    notification body label (src/components/notifications/Body/index.tsx),
#    shared by the popup and the bar's notification menu. No config key or CSS
#    path exposes it. See upstream issues #894 and #1115 (unfixed). We attach
#    tooltipText so the full body shows on hover, without touching the layout.
#
# 2. Keep settings when a config read comes back empty.
#    HyprPanel watches config.json and re-syncs every option on each change.
#    The sync reads the file and, when the read returns empty, treats every
#    option as absent and resets it to default in memory (writeDisk:false), so
#    the bar drops the user theme and layout while the file on disk stays
#    intact. A restart reloads the file and looks like a fix. The empty read is
#    transient, so we guard the sync: an empty config is never a reason to wipe
#    live settings, only a read to skip until the next change.
final: prev:

{
  hyprpanel = prev.hyprpanel.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/components/notifications/Body/index.tsx \
        --replace-fail \
          'onRealize={(self) => self.set_markup(escapeMarkup(notification.body))}' \
          'tooltipText={notification.body}
                onRealize={(self) => self.set_markup(escapeMarkup(notification.body))}'

      substituteInPlace src/lib/options/optionRegistry/index.ts \
        --replace-fail \
          'const newConfig = this._configManager.readConfig();' \
          'const newConfig = this._configManager.readConfig();

        if (Object.keys(newConfig).length === 0) {
            return;
        }'
    '';
  });
}
