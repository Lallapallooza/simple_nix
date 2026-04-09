# Periodic check for upstream config changes.
#
# Fetches origin/main and notifies the user if the local branch is behind.
# The user rebuilds manually when ready.
#
# Enabled by default (host.autoUpgrade = true).  Set to false in host.nix to disable.
{ lib, pkgs, host, ... }:

let
  checkScript = pkgs.writeShellScript "nixos-update-check" ''
    set -euo pipefail

    cd "${host.repoDir}"
    ${pkgs.git}/bin/git fetch --quiet origin main

    behind=$(${pkgs.git}/bin/git rev-list --count HEAD..origin/main)
    [ "$behind" -eq 0 ] && rm -f "${host.homeDir}/.local/state/nixos-update-available" && exit 0

    msg="NixOS config is $behind commit(s) behind origin/main. Run: cd ${host.repoDir} && git pull && ./install.sh"

    ${pkgs.coreutils}/bin/mkdir -p "${host.homeDir}/.local/state"
    echo "$msg" > "${host.homeDir}/.local/state/nixos-update-available"

    # Best-effort desktop notification
    uid=$(${pkgs.coreutils}/bin/id -u)
    if [ -S "/run/user/$uid/bus" ]; then
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        ${pkgs.libnotify}/bin/notify-send -u normal \
          "NixOS Update Available" \
          "$behind new commit(s) on origin/main"
    fi
  '';
in
{
  systemd.services.nixos-update-check = lib.mkIf host.autoUpgrade {
    description = "Check for upstream NixOS config updates";
    serviceConfig = {
      Type = "oneshot";
      User = host.username;
      ExecStart = checkScript;
    };
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  systemd.timers.nixos-update-check = lib.mkIf host.autoUpgrade {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
  };
}
