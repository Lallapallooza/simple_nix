{ config, pkgs, ... }:

{
  # SSH -- route GitHub traffic through the agenix-managed key
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."github.com" = {
      identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519_github";
    };
  };

  # Zsh with oh-my-zsh and powerlevel10k prompt
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "z" "sudo" "extract" "command-not-found" "fzf" "docker" ];
    };
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];
    initContent = ''
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

      # Alert on failed auto-rebuild (persistent marker written by nixos-rebuild-notify-failure)
      if [[ -f ~/.local/state/nixos-rebuild-failed ]]; then
        printf '\e[1;31m%s\e[0m\n' "$(cat ~/.local/state/nixos-rebuild-failed)"
        rm -f ~/.local/state/nixos-rebuild-failed
      fi

      # Import SSH_AUTH_SOCK from systemd (gnome-keyring / gcr-ssh-agent)
      if [[ -z "$SSH_AUTH_SOCK" ]]; then
        for _sock in "$XDG_RUNTIME_DIR/gcr/ssh" "$XDG_RUNTIME_DIR/keyring/ssh"; do
          if [[ -S "$_sock" ]]; then export SSH_AUTH_SOCK="$_sock"; break; fi
        done
        unset _sock
      fi

      # Redirect "sudo vim/nvim <file>" to "sudoedit <file>" (safer, uses $EDITOR).
      # Only catches the simple case; "sudo -E vim" etc. bypass this.
      sudo() {
        if [[ "$1" == "vim" || "$1" == "nvim" ]]; then
          shift
          command sudoedit "$@"
        else
          command sudo "$@"
        fi
      }
    '';
  };
}
