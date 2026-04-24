{ lib, host, ... }:

{
  # --- Keyring ---
  # gnome-keyring for storing secrets (Brave sync, SSH keys, etc.) -- kwallet disabled
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.sddm.enableKwallet = lib.mkForce false;
  security.pam.services.login.enableKwallet = lib.mkForce false;

  # PAM service for hyprlock -- without this, hyprlock can't authenticate to unlock
  security.pam.services.hyprlock = {};

  # --- Sudo ---
  # NixOS does not include /etc/sudoers.d by default; the directive below makes
  # sudo read drop-in rules from it. Used by scripts/setup_profiling.sh to install
  # a session-scoped NOPASSWD rule for BCC tools, removed on --reset.
  security.sudo.extraConfig = ''
    @includedir /etc/sudoers.d
  '';

  # --- SSH ---
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ host.username ];
    };
    extraConfig = "MaxAuthTries 3";
  };

  # Agenix -- age-encrypted secrets decrypted at activation time
  # Tries host SSH key first, falls back to personal age key (for new machine bootstrap)
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "${host.homeDir}/.config/age/keys.txt"
  ];
  age.secrets.id_ed25519_github = {
    file = ./secrets/id_ed25519_github.age;
    path = "${host.homeDir}/.ssh/id_ed25519_github";
    owner = host.username;
    group = "users";
    mode = "0600";
  };

  # Decrypted to /run/agenix/openrouter-api-key (read manually or via EnvironmentFile)
  age.secrets.openrouter-api-key = {
    file = ./secrets/openrouter-api-key.age;
    owner = host.username;
    group = "users";
    mode = "0600";
  };
  # --- Firewall ---
  # NixOS enables firewall by default; make policy explicit
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];   # openssh module auto-opens 22
    allowedUDPPorts = [ ];
  };

  # --- System Health ---
  services.earlyoom.enable = true;      # Kill runaway processes before OOM freezes the desktop
  services.journald.extraConfig = "SystemMaxUse=500M";   # Cap journal logs (default is ~4GB)
}
