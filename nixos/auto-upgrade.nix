# Custom auto-rebuild instead of system.autoUpgrade.
#
# system.autoUpgrade has multiple open bugs on desktop + flake systems:
#   - Service hangs indefinitely when a flake input changes (NixOS/nixpkgs#347315)
#   - Silent downgrade when GitHub API is unreachable (NixOS/nixpkgs#468878)
#   - Bypasses CPU/IO scheduling, freezes desktop during rebuild (NixOS Discourse#23820)
#   - Relies on deprecated --update-input flag (NixOS/nixpkgs#349734)
#
# This timer pulls the latest main branch into a local checkout, then rebuilds at low
# priority.  The local checkout has hardware-configuration.nix (which is gitignored and
# not on GitHub), so the build succeeds.  Only the overlay hashes change via CI -- flake
# inputs stay pinned to whatever is in flake.lock (manual `nix flake update`).
#
# Enabled by default (host.autoUpgrade = true).  Set to false in host.nix to disable.
{ config, lib, pkgs, host, ... }:

let
  repoDir = host.repoDir;

  rebuildScript = pkgs.writeShellScript "nixos-auto-rebuild" ''
    set -euo pipefail

    # Pull as repo owner (not root) to preserve file ownership
    ${pkgs.util-linux}/bin/runuser -u ${host.username} -- \
      ${pkgs.git}/bin/git -C "${repoDir}" fetch --quiet origin main

    # Stash any local changes so merge --ff-only doesn't fail on a dirty tree
    ${pkgs.util-linux}/bin/runuser -u ${host.username} -- \
      ${pkgs.git}/bin/git -C "${repoDir}" stash --quiet 2>/dev/null || true
    ${pkgs.util-linux}/bin/runuser -u ${host.username} -- \
      ${pkgs.git}/bin/git -C "${repoDir}" merge --ff-only origin/main
    ${pkgs.util-linux}/bin/runuser -u ${host.username} -- \
      ${pkgs.git}/bin/git -C "${repoDir}" stash pop --quiet 2>/dev/null || true

    # Rebuild from local checkout at low priority
    exec ${pkgs.util-linux}/bin/ionice -c 3 \
      ${pkgs.coreutils}/bin/nice -n 19 \
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch \
        --flake "${repoDir}/nixos#${host.hostname}"
  '';
in
{
  systemd.services.nixos-rebuild-flake = lib.mkIf host.autoUpgrade {
    description = "Pull latest config and rebuild NixOS";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = rebuildScript;
      StandardOutput = "journal";
      StandardError = "journal";
      TimeoutStartSec = "30min";
    };
    onFailure = [ "nixos-rebuild-notify-failure.service" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.nix pkgs.git pkgs.coreutils pkgs.gnutar pkgs.gzip ];
  };

  systemd.services.nixos-rebuild-notify-failure = lib.mkIf host.autoUpgrade {
    description = "Notify on NixOS rebuild failure";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "nixos-rebuild-notify" ''
        msg="NixOS auto-rebuild failed at $(date). Check: journalctl -u nixos-rebuild-flake"

        # Persistent marker -- shown on next interactive login via shell initContent
        state_dir="${host.homeDir}/.local/state"
        ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
        echo "$msg" > "$state_dir/nixos-rebuild-failed"
        ${pkgs.coreutils}/bin/chown ${host.username}:users "$state_dir/nixos-rebuild-failed"

        # Best-effort: wall (terminals) + desktop notification (D-Bus session)
        ${pkgs.util-linux}/bin/wall "$msg" 2>/dev/null || true
        uid=$(${pkgs.coreutils}/bin/id -u ${host.username})
        if [ -S "/run/user/$uid/bus" ]; then
          DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
            ${pkgs.util-linux}/bin/runuser -u ${host.username} -- \
            ${pkgs.libnotify}/bin/notify-send -u critical \
              "NixOS Auto-Rebuild Failed" \
              "Check: journalctl -u nixos-rebuild-flake"
        fi
      '';
    };
  };

  systemd.timers.nixos-rebuild-flake = lib.mkIf host.autoUpgrade {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
  };
}
