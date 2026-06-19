# Overlay: notification body tooltip.
#
# HyprPanel hardcodes lines=2 + maxWidthChars=35 + truncate on the notification
# body label (src/components/notifications/Body/index.tsx), shared by the popup
# and the bar's notification menu. No config key or CSS path exposes it. See
# upstream issues #894 and #1115 (unfixed). We attach tooltipText so the full
# body shows on hover, without touching the layout. ags.bundle re-runs the
# bundler during the build, so the tooltip lands in bin/.hyprpanel-wrapped.
final: prev:

{
  hyprpanel = prev.hyprpanel.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/components/notifications/Body/index.tsx \
        --replace-fail \
          'onRealize={(self) => self.set_markup(escapeMarkup(notification.body))}' \
          'tooltipText={notification.body}
                onRealize={(self) => self.set_markup(escapeMarkup(notification.body))}'
    '';
  });
}
