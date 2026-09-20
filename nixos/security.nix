{ lib, host, ... }:

let
  # Common ownership for user-scoped secrets
  userSecret = {
    owner = host.username;
    group = "users";
    mode = "0600";
  };
in
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

  # --- Secrets (agenix) ---
  # age-encrypted files decrypted at activation time.
  # Tries host SSH key first, falls back to personal age key (for new machine bootstrap).
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "${host.homeDir}/.config/age/keys.txt"
  ];

  # SSH keys -- symlinked into ~/.ssh
  age.secrets.id_ed25519_github = userSecret // {
    file = ./secrets/id_ed25519_github.age;
    path = "${host.homeDir}/.ssh/id_ed25519_github";
  };
  age.secrets.aws-default-key-pair = userSecret // {
    file = ./secrets/aws-default-key-pair.age;
    path = "${host.homeDir}/.ssh/aws-default-key-pair.pem";
  };

  # API keys / credentials -- decrypted to /run/agenix/<name>, read manually or via EnvironmentFile
  age.secrets.openrouter-api-key = userSecret // {
    file = ./secrets/openrouter-api-key.age;
  };
  age.secrets.aws-access-key-id = userSecret // {
    file = ./secrets/aws-access-key-id.age;
  };
  age.secrets.aws-secret-access-key = userSecret // {
    file = ./secrets/aws-secret-access-key.age;
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
  services.journald.settings.Journal.SystemMaxUse = "500M";   # Cap journal logs (default is ~4GB)
}
