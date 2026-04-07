# NixOS Desktop Config

Modular NixOS configuration with Hyprland (UWSM) + Plasma 6 fallback, SDDM display manager.

<p align="center">
  <img src="resources/desktop.png" width="100%">
</p>
<p align="center">
  <img src="resources/windows.png" width="24%">
  <img src="resources/code1.png" width="24%">
  <img src="resources/code2.png" width="24%">
  <img src="resources/code3.png" width="24%">
</p>

## Structure

```
nixos/                   # NixOS system config (flake-based)
  flake.nix              # inputs: nixpkgs-unstable, home-manager, agenix, lanzaboote
  host.nix               # machine-specific constants (edit for new PCs)
  configuration.nix      # entry point
  hardware.nix           # boot, kernel, NVIDIA, CPU, bluetooth
  hardware-configuration.nix  # auto-generated (nixos-generate-config)
  desktop.nix            # SDDM, Hyprland, Plasma, portals, audio, fonts
  security.nix           # SSH, PAM, gnome-keyring, agenix
  programs.nix           # system packages, steam, docker, flatpak
  auto-upgrade.nix       # nightly rebuild from local clone via systemd timer
  nordvpn.nix            # NordVPN daemon + GUI (FHS-wrapped from .deb)
  overlays/cli-tools.nix # version overlay for AI coding tools
  home/                  # home-manager modules
scripts/
  update-tools.sh        # bump AI tool versions + hashes
  add-secret.sh          # add and wire up a new agenix secret
config/                  # dotfiles (most symlinked by link.sh)
  nvim/                  # Neovim (NvChad), symlinked
  hypr/                  # Hyprland user config, symlinked
  kitty/                 # terminal, symlinked
  hyprpanel/             # status bar, symlinked
  rofi/                  # app launcher, symlinked
  p10k/                  # Powerlevel10k prompt, symlinked
  clangd/                # clangd config, symlinked
  gtk-3.0/, gtk-4.0/     # GTK accent overrides (home-manager)
  mc/                    # Midnight Commander (home-manager)
  kde/                   # KDE color scheme (home-manager)
skills/                  # AI agent skills (see skills/README.md)
wallpapers/              # wallpaper images (gitignored)
```

## Quick Start

### 0. Clone

```bash
git clone https://github.com/Lallapallooza/simple_nix.git
cd simple_nix
```

### 1. Edit `nixos/host.nix`

All machine-specific values live here:

```nix
{
  username = "my_username";
  # homeDir is derived as /home/${username} in flake.nix
  hostname = "nixos";
  timezone = "Europe/Dublin";
  defaultLocale = "en_US.UTF-8";
  regionalLocale = "en_IE.UTF-8";
  tmpfsSize = "16G";           # ~half of RAM
  steamScaling = "1.666667";   # match your monitor scale
  cursorSize = 24;             # 16@1x, 24@1.5x, 32@2x
  nvidia = true;               # false for AMD/Intel GPU
  repoDir = "/home/my_username/code/simple_nix";  # local clone path (for auto-upgrade)
  autoUpgrade = true;          # nightly rebuild from local clone (git pull + rebuild)
}
```

### 2. Edit `config/hypr/user.conf`

Hyprland config is plain text (not Nix), edit manually:

```ini
# Monitor
monitor = DP-4, 3840x2160@240, 0x0, 1.666667
#         ^^^^  ^^^^^^^^^^^^^^       ^^^^^^^^
#         connector  resolution+hz   scale factor

# Scaling (must match your monitor scale)
env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24
env = GDK_SCALE,2
env = GDK_DPI_SCALE,0.8333

# NVIDIA-specific (set to false/0 on AMD/Intel)
xwayland { force_zero_scaling = true }
cursor { no_hardware_cursors = true }
```

### 3. Build

```bash
./install.sh
```

Relog (SDDM) to pick up the new Hyprland session.

### Known issues

- **Telegram steals focus on new messages** -- Telegram's "Draw attention to the window" feature uses Wayland activation, which Hyprland treats as a focus request. Go to Telegram -> Settings -> Notifications -> disable **Draw attention to the window**. See [hyprwm/Hyprland#9186](https://github.com/hyprwm/Hyprland/issues/9186).

## Deployment

- **home-manager** deploys mc and kde as nix store symlinks (`./install.sh` to apply)
- **link.sh** symlinks everything else for live editing (no rebuild needed)

## Dev Environment

- **nix-ld** enabled -- pip wheels, npm native modules, and other binary packages just work
- **direnv** for per-project environments -- drop a `.envrc` and tools auto-activate on `cd`:
  ```bash
  # Python venv
  echo 'source .venv/bin/activate' > .envrc && direnv allow

  # Nix shell
  echo 'use nix' > .envrc && direnv allow
  ```
- **Python**: uv, basedpyright + ruff, Python 3.13. PyTorch wheels bundle their own CUDA runtime -- `uv pip install torch` works with nix-ld
- **C/C++**: clang, clangd, cmake. NixOS pitfall -- clangd can't find standard headers without this in CMakeLists.txt:
  ```cmake
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
  set(CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES})
  ```
  Then: `ln -s build/compile_commands.json .`
- **Rust**: rustc, cargo, rust-analyzer
- **Go**: go, gopls
- **JVM**: JDK, Kotlin, kotlin-language-server
- **Neovim**: NvChad-based, LSPs from nix (clangd, basedpyright, ruff, rust-analyzer, ts_ls, bashls), conform.nvim for formatting. See [`config/nvim/CHEATSHEET.md`](config/nvim/CHEATSHEET.md)
- **AI coding tools**: claude-code, gemini-cli, codex, opencode are managed via a [version overlay](#auto-updating-cli-tools) that stays ahead of nixpkgs

## Theme

Ayu Dark everywhere. One palette, every app.

Stock Ayu Dark looks great out of the box but collapses several semantic roles to the same color. Parameters and constants/numbers are both purple (`#D2A6FF`) -- you can't tell a function argument from a numeric literal. Properties and library functions share coral (`#F07178`). The two blues (`#39BAE6` for built-in types and `#59C2FF` for user types) are hard to tell apart in practice.

This config fixes those collisions with a 10-group system. Parameters stay purple, but constants get their own muted gold (`#C4B070`). Properties move to mint (`#80DDB8`). Self/builtins get cyan (`#39BAE6`), clearly distinct from type blue (`#59C2FF`). The foreground is dimmed to `#B8B5AC` (stock is brighter `#BFBDB6`) so accent colors pop above the text ground level. Constants and operators are pushed below foreground brightness -- they recede so the important tokens stand out.

| Role | Hex | Used for |
|------|-----|----------|
| Background | `#0B0E14` | kitty, hyprlock, hyprpanel, KDE, rofi |
| Surface | `#14171D` | rofi bg-alt, hyprpanel cards, KDE Window bg |
| Border | `#1A1D23` | Hyprland inactive border, hyprpanel borders |
| Foreground | `#B8B5AC` | kitty, hyprlock, hyprpanel, KDE, rofi |
| Dimmed | `#3D4046` | kitty bright-black, disabled states |
| Accent | `#FF8F40` | Hyprland borders, hyprlock, hyprpanel, kitty cursor, rofi, GTK, KDE |
| Red | `#F07178` | errors, destructive actions |
| Green | `#AAD94C` | strings, success states |
| Yellow | `#E6C54C` | warnings, functions (neovim) |
| Blue | `#59C2FF` | types, links, info |
| Purple | `#D2A6FF` | parameters, lifetimes |
| Cyan | `#39BAE6` | self/builtins |
| Mint | `#80DDB8` | properties, regex, special chars |
| Orange | `#FF7733` | keywords (neovim anchor color) |

### Neovim: 10-group syntax highlighting

1. **Keywords** `#FF7733` orange -- the anchor color everything else is tuned against
2. **Functions** `#E6C54C` gold -- warm but 22 degrees from keyword orange on the hue wheel
3. **Strings** `#AAD94C` green -- standard, distinct from everything
4. **Types+Modules** `#59C2FF` blue -- structs, classes, imports, tags
5. **Constants** `#C4B070` muted gold -- intentionally dimmer than fg so they recede
6. **Self/Builtins** `#39BAE6` cyan -- `self`, `this`, `__init__`
7. **Properties** `#80DDB8` mint -- struct fields, object members
8. **Parameters** `#D2A6FF` purple -- function arguments, lifetimes
9. **Decorators** `#E6C08A` beige -- `@decorator`, `#[attr]`, macros
10. **Operators** `#CC7832` dark orange -- quiet scaffolding, doesn't compete with keywords

Design choices:
- **No italic** anywhere -- keeps monospace grid clean
- **CVD-aware** -- tested for mild red-green color vision deficiency; no meaning carried by red-green contrast alone
- **LSP semantic tokens enabled** -- treesitter handles syntax, LSP adds type-level precision; empty `@lsp.type.variable = {}` lets treesitter's more specific groups show through
- **Foreground dimmed to `#B8B5AC`** -- stock is brighter `#BFBDB6`; dimming gives accent colors more contrast

### Desktop theming

Applied via:
- **kitty** -- 16 terminal colors + cursor/selection in `kitty.conf`
- **KDE** -- full Ayu Dark color scheme in `kdeglobals` (deployed by home-manager)
- **GTK 3/4** -- accent, destructive, success, warning, error overrides in `gtk.css`
- **rofi** -- custom `ayu-dark.rasi` theme
- **hyprpanel** -- custom `config.json` with Ayu Dark palette
- **hyprlock** -- blurred background with Ayu Dark text/input colors
- **Hyprland** -- border colors use accent orange

## Secure Boot (dual-boot with Windows)

NixOS boots through Secure Boot via [Lanzaboote](https://github.com/nix-community/lanzaboote), which signs systemd-boot stubs with custom keys. Microsoft's keys are kept alongside for Windows compatibility.

After a fresh install or on a new machine:

```bash
# 1. Generate Secure Boot signing keys
sudo nix-shell -p sbctl --run "sbctl create-keys"

# 2. Build and sign (keys must exist before rebuild)
./install.sh

# 3. Verify all boot entries are signed (kernel-* unsigned is expected)
sudo nix-shell -p sbctl --run "sbctl verify"
```

Then configure the BIOS (ASRock Taichi X870E shown, other boards similar):

```
4. Reboot into BIOS (F2/Del), Advanced Mode (F6)
5. Security > Secure Boot > Secure Boot Mode = Custom
6. Clear Secure Boot Keys > Yes
7. F10 save, boot back into NixOS
```

```bash
# 8. Enroll your keys + Microsoft's (--microsoft is mandatory for dual-boot)
sudo nix-shell -p sbctl --run "sbctl enroll-keys --microsoft"
```

```
9.  Reboot into BIOS (F2/Del)
10. Security > Secure Boot = Enabled
11. F10 save
```

```bash
# 12. Verify -- should show "Secure Boot: enabled (user)"
bootctl status
```

To boot Windows: press F11 at POST for the boot device menu, select the Windows drive. BitLocker will ask for the recovery key once after key enrollment, then re-seals automatically.

## Auto-Updating CLI Tools

AI coding tools (claude-code, gemini-cli, codex, opencode) update faster than nixpkgs can merge PRs. Rather than wait 1-2 weeks, a version overlay bumps them ahead of nixpkgs automatically.

### How it works

```
nixos/overlays/cli-tools.nix   # version pins + hashes (patched by the update script)
scripts/update-tools.sh        # checks npm/GitHub, computes hashes, patches the overlay
.github/workflows/             # CI checks every 6h, creates a PR on change
nixos/auto-upgrade.nix         # systemd timer: git pull + rebuild nightly at 04:00 (enabled by default)
```

The nightly auto-upgrade is **enabled by default** (`autoUpgrade = true` in `host.nix`). It pulls the latest `main` into your local clone (picking up CI-pushed tool updates), then rebuilds from the local checkout. Set to `false` to disable.

When nixpkgs catches up or passes the overlay version, the overlay becomes a no-op -- the nixpkgs package is used as-is with zero overhead.

### Manual update

```bash
./scripts/update-tools.sh              # bump all tools
./scripts/update-tools.sh --tool codex # bump one tool
./scripts/update-tools.sh --dry-run    # preview without changing files
./install.sh                           # apply
```

## Secrets

Secrets are managed with [agenix](https://github.com/ryantm/agenix) -- age-encrypted files committed to the repo. Ciphertext is safe to publish; only holders of the private key can decrypt.

Two decryption keys are configured in `nixos/secrets/secrets.nix`:
- **Personal age key** -- portable, stored in a password manager. Use this to bootstrap new machines.
- **Machine host key** -- per-machine SSH host key for unattended decryption at boot.

### Using your own secrets

To use this config with your own secrets:

```bash
# 1. Generate a personal age key (store the private key in your password manager!)
age-keygen -o ~/.config/age/keys.txt

# 2. Get your machine's host key
cat /etc/ssh/ssh_host_ed25519_key.pub

# 3. Edit nixos/secrets/secrets.nix -- replace both keys with yours
#    vitalii = "age1...";   <-- your age public key (from step 1)
#    nixos = "ssh-ed25519 AAAA...";   <-- your host key (from step 2)

# 4. Create your GitHub SSH key secret
cd nixos/secrets
agenix -e id_ed25519_github.age -i ~/.config/age/keys.txt
# (paste your GitHub SSH private key, save)

# 5. Build
./install.sh
```

### Adding a new machine

```bash
# On the new machine:
# 1. Copy your personal age key from password manager to ~/.config/age/keys.txt
# 2. Add the new machine's host key to nixos/secrets/secrets.nix
cat /etc/ssh/ssh_host_ed25519_key.pub
# 3. Re-encrypt all secrets for the new recipient (from any machine that can decrypt)
cd nixos/secrets && agenix -r -i ~/.config/age/keys.txt
# 4. Commit, push, then install on the new machine
./install.sh
```

### Adding more secrets

```bash
# Interactive: prompts for the secret value (hidden input)
./scripts/add-secret.sh my-api-key

# It will:
#   1. Encrypt the value to nixos/secrets/my-api-key.age
#   2. Add the entry to secrets.nix automatically
#   3. Wire it up in security.nix

# Then apply
./install.sh
```

## Wallpaper

Place a wallpaper image in `wallpapers/wallpaper.png` (gitignored). `link.sh` will symlink it to `~/Pictures/wallpaper.png`, where `hyprpaper` picks it up.

To use a different image, replace the file or edit `config/hypr/hyprpaper.conf`.
