# NordVPN daemon (CLI) + GUI (Flutter/GTK3).
#
# Based on https://github.com/chomes/nix_modules/blob/main/nordvpn-module.nix
# Extended with the official nordvpn-gui Flutter app from repo.nordvpn.com.
{ lib, pkgs, host, ... }:

let
  version = "4.5.0";

  # -- CLI + daemon (FHS-wrapped) ----------------------------------------
  nordVpnBase = pkgs.stdenv.mkDerivation {
    pname = "nordvpn-base";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/n/nordvpn/nordvpn_${version}_amd64.deb";
      hash = "sha256-bekJOzhLGwFsYRuPagANwUduyCufaU4XoJPwWoBniR8=";
    };
    buildInputs = with pkgs; [ libxml2 libidn2 libnl libcap_ng sqlite ];
    nativeBuildInputs = with pkgs; [ dpkg autoPatchelfHook stdenv.cc.cc.lib ];
    dontConfigure = true;
    dontBuild = true;
    unpackPhase = ''
      runHook preUnpack
      dpkg --extract $src .
      runHook postUnpack
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      mv usr/* $out/
      mv var/ $out/
      mv etc/ $out/
      runHook postInstall
    '';
  };

  nordVpnDaemon = pkgs.buildFHSEnv {
    name = "nordvpnd";
    runScript = "nordvpnd";
    targetPkgs = _: with pkgs; [
      sqlite nordVpnBase sysctl iptables iproute2 procps cacert
      libxml2 libnl libcap_ng libidn2 zlib wireguard-tools
    ];
  };

  nordVpnPkg = pkgs.stdenv.mkDerivation {
    pname = "nordvpn";
    inherit version;
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/share
      ln -s ${nordVpnBase}/bin/nordvpn $out/bin
      ln -s ${nordVpnDaemon}/bin/nordvpnd $out/bin
      ln -s ${nordVpnBase}/share/* $out/share/
      ln -s ${nordVpnBase}/var $out/
      runHook postInstall
    '';
    meta = with lib; {
      description = "CLI client for NordVPN";
      homepage = "https://www.nordvpn.com";
      license = licenses.unfreeRedistributable;
      platforms = [ "x86_64-linux" ];
    };
  };

  # -- GUI (Flutter/GTK3, FHS-wrapped) -----------------------------------
  nordVpnGuiBase = pkgs.stdenv.mkDerivation {
    pname = "nordvpn-gui-base";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/n/nordvpn-gui/nordvpn-gui_${version}_amd64.deb";
      hash = "sha256-V1eOPudlBhVH5cSjp9qtpL6zJDSq4e9MQ8YZXnMcH84=";
    };
    nativeBuildInputs = [ pkgs.dpkg ];
    dontConfigure = true;
    dontBuild = true;
    unpackPhase = ''
      runHook preUnpack
      dpkg --extract $src .
      runHook postUnpack
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r opt/nordvpn-gui/* $out/
      mkdir -p $out/share
      cp -r usr/share/* $out/share/
      runHook postInstall
    '';
  };

  nordVpnGui = pkgs.buildFHSEnv {
    name = "nordvpn-gui";
    runScript = "${nordVpnGuiBase}/nordvpn-gui";
    targetPkgs = _: with pkgs; [
      nordVpnGuiBase
      gtk3 gdk-pixbuf pango cairo harfbuzz atk glib
      libx11 libxcursor libxrandr libxi libxext libxcomposite libxdamage libxfixes libxtst
      libepoxy fontconfig freetype libGL mesa
      dbus
      stdenv.cc.cc.lib
    ];
    extraInstallCommands = ''
      mkdir -p $out/share/applications $out/share/icons
      cp -r ${nordVpnGuiBase}/share/applications/* $out/share/applications/ 2>/dev/null || true
      cp -r ${nordVpnGuiBase}/share/icons/* $out/share/icons/ 2>/dev/null || true
      # Fix Exec path in .desktop file
      substituteInPlace $out/share/applications/nordvpn-gui.desktop \
        --replace-fail "Exec=nordvpn-gui" "Exec=$out/bin/nordvpn-gui"
    '';
  };

in {
  environment.systemPackages = [ nordVpnPkg nordVpnGui ];

  users.groups.nordvpn = {};

  # NordVPN requires relaxed reverse path filtering (asymmetric routing through tunnel).
  # "loose" still rejects spoofed source addresses while allowing VPN traffic.
  networking.firewall.checkReversePath = "loose";

  systemd.services.nordvpn = {
    description = "NordVPN daemon";
    serviceConfig = {
      ExecStart = "${nordVpnPkg}/bin/nordvpnd";
      ExecStartPre = pkgs.writeShellScript "nordvpn-start" ''
        mkdir -m 700 -p /var/lib/nordvpn
        if [ -z "$(ls -A /var/lib/nordvpn)" ]; then
          cp -r ${nordVpnPkg}/var/lib/nordvpn/* /var/lib/nordvpn
          chmod -R u+w /var/lib/nordvpn
        fi
      '';
      NonBlocking = true;
      KillMode = "process";
      Restart = "on-failure";
      RestartSec = 5;
      RuntimeDirectory = "nordvpn";
      RuntimeDirectoryMode = "0750";
      Group = "nordvpn";
    };
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
