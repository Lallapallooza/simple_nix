let
  # Personal age key (portable -- store private key in password manager)
  vitalii = "age1ujz6pq06c08j943lkl2mmtp2mf6wvksygddddt58qt802lmuh9qqmu53yr";

  # Machine host key (for unattended decryption at boot)
  nixos = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINaEhNq5blLJu8Z2J0Byl9nULJZiUOPnBGL/Za0Q18iD";
in
{
  "id_ed25519_github.age".publicKeys = [ vitalii nixos ];
  "openrouter-api-key.age".publicKeys = [ vitalii nixos ];
}
