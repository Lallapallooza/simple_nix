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
  update-check.nix       # nightly check for upstream changes + notification
  nordvpn.nix            # NordVPN daemon + GUI (FHS-wrapped from .deb)
  home/                  # home-manager modules
scripts/
  install-ai-tools.sh    # local CLI + desktop installs for Claude and ChatGPT
  ai-desktop-launcher.sh # NixOS runtime libraries for the locally installed GUIs
  add-secret.sh          # add and wire up a new agenix secret
config/                  # dotfiles (most symlinked by link.sh)
  nvim/                  # Neovim (NvChad), symlinked
  hypr/                  # Hyprland user config, symlinked
  kitty/                 # terminal, symlinked
  wayle/                 # status bar, symlinked
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
  repoDir = "/home/my_username/code/simple_nix";  # local clone path (for update checks)
  updateCheck = true;          # fetch origin/main nightly and notify; never pull or rebuild
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
- **Screen share picker does nothing (Discord, etc.)** -- when `xdg-desktop-portal-hyprland` restarts without the `xdg-desktop-portal` frontend restarting too, the frontend keeps a stale capability cache and advertises zero capturable sources, so `SelectSources` hangs and no picker ever opens. Resync them with `systemctl --user restart xdg-desktop-portal.service`; it recurs on any backend-only restart (compositor restart, portal update).

## Deployment

- **home-manager** deploys mc and kde as nix store symlinks (`./install.sh` to apply)
- **link.sh** symlinks everything else for live editing (no rebuild needed)

## Razer mouse

[OpenRazer](https://openrazer.github.io/) supplies the driver and user daemon;
[Polychromatic](https://polychromatic.app/) supplies the settings GUI. The Razer
Viper V3 Pro is supported, including USB IDs `1532:00c0` and `1532:00c1`.

After the first rebuild, reboot to load the driver and pick up membership in the
`openrazer` group. Open **Polychromatic** from the application launcher, or run
`polychromatic-controller`, to configure DPI, polling rate, and supported power
settings. The daemon starts with the graphical session and provides battery
notifications.

This covers the mouse's basic hardware settings. Button remapping, Hypershift,
and firmware updates are [not supported by OpenRazer/Polychromatic](https://docs.polychromatic.app/openrazer/).

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
- **AI tools**: Claude Code, Codex, ChatGPT Desktop, and Claude Desktop install locally via [`scripts/install-ai-tools.sh`](#ai-tools) and update independently of OS rebuilds
- **AMD uProf** (optional, AMD CPUs only) -- microarchitectural profiler: IBS sampling, Zen PMU counters, cache/mem/branch/TLB events, power timechart. See [AMD uProf setup](#amd-uprof-optional)
- **NVIDIA Nsight Graphics** (optional, NVIDIA GPUs only) -- headless frame debugger and GPU profiler CLI for Vulkan/OpenGL/DirectX. See [Nsight Graphics setup](#nvidia-nsight-graphics-optional)

## Theme

Ayu Dark everywhere. One palette, every app.

Stock Ayu Dark looks great out of the box but collapses several semantic roles to the same color. Parameters and constants/numbers are both purple (`#D2A6FF`) -- you can't tell a function argument from a numeric literal. Properties and library functions share coral (`#F07178`). The two blues (`#39BAE6` for built-in types and `#59C2FF` for user types) are hard to tell apart in practice.

This config fixes those collisions with a 10-group system. Parameters stay purple, but constants get their own muted gold (`#C4B070`). Properties move to mint (`#80DDB8`). Self/builtins get cyan (`#39BAE6`), clearly distinct from type blue (`#59C2FF`). The foreground is dimmed to `#B8B5AC` (stock is brighter `#BFBDB6`) so accent colors pop above the text ground level. Constants and operators are pushed below foreground brightness -- they recede so the important tokens stand out.

| Role | Hex | Used for |
|------|-----|----------|
| Background | `#0B0E14` | kitty, hyprlock, wayle, KDE, rofi |
| Surface | `#14171D` | rofi bg-alt, wayle cards, KDE Window bg |
| Border | `#1A1D23` | Hyprland inactive border, wayle borders |
| Foreground | `#B8B5AC` | kitty, hyprlock, wayle, KDE, rofi |
| Dimmed | `#3D4046` | kitty bright-black, disabled states |
| Accent | `#FF8F40` | Hyprland borders, hyprlock, wayle, kitty cursor, rofi, GTK, KDE |
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
- **Midnight Commander** -- custom truecolor `ayu-dark` skin in
  `config/mc/skins/ayu-dark.ini`, with a subtle dark selection and orange text,
  blue directories, green executables, cyan links, and thin borders.
  Home-manager installs it into `~/.local/share/mc/skins/` and selects it in `mc/ini`.
  Preview without rebuilding: `mc -S "$PWD/config/mc/skins/ayu-dark.ini"`
  The F2 menu keeps the packaged actions and adds **Shift+D** to drag the current
  file (or tagged files) from Kitty into a GUI app. Drag from the Kitty interface;
  it returns to MC after a successful drop, or press Esc to cancel. The original
  tagged duplicate-delete action is on **Shift+E**.
  The helper exports the selected files through the document portal with
  session-only read access for Discord's Flatpak, so files can come from any
  readable folder without configuring a list of allowed directories.
- **VS Code** -- local theme extension in `config/vscode/`, carrying both the
  desktop palette and the 10-group syntax system. The terminal's 16 ANSI slots
  are copied from `kitty.conf` so an integrated terminal matches a kitty window.
  See `config/vscode/README.md`
- **KDE** -- full Ayu Dark color scheme in `kdeglobals` (deployed by home-manager)
- **GTK 3/4** -- accent, destructive, success, warning, error overrides in `gtk.css`
- **rofi** -- custom `ayu-dark.rasi` theme
- **wayle** -- custom `config.toml` with the Ayu Dark palette mapped onto Wayle's
  10 semantic color slots (purple `#D2A6FF` has no slot, so the modules that use
  it carry the hex inline)
- **hyprlock** -- blurred background with Ayu Dark text/input colors
- **Hyprland** -- border colors use accent orange

## AMD uProf (optional)

AMD uProf isn't in nixpkgs -- AMD gates every download behind a EULA form, so no fetchurl is possible. The overlay at `nixos/overlays/amduprof.nix` handles it via `requireFile`: you download the tarball once, add it to the Nix store, set a flag, rebuild.

Gated by `amduprof` in `host.nix`. Leave it `false` (default) and `install.sh` works on any machine without the tarball.

### One-time setup

```bash
# 1. Download AMDuProf_Linux_x64_<version>.tar.bz2 (~300 MB) from:
#      https://www.amd.com/en/developer/uprof.html
#    (The version pinned in the overlay is 5.2.606 -- bump `uprofVersion`
#     there if you grab a newer release.)

# 2. Compute its hash and paste into `uprofHash` in
#    nixos/overlays/amduprof.nix:
nix hash file ~/Downloads/AMDuProf_Linux_x64_5.2.606.tar.bz2

# 3. Add the tarball to the Nix store:
nix store add-file ~/Downloads/AMDuProf_Linux_x64_5.2.606.tar.bz2

# 4. Enable the flag in nixos/host.nix:
#      amduprof = true;

# 5. Rebuild
./install.sh
```

Afterwards `AMDuProfCLI`, `AMDuProfPcm`, and `AMDuProfCfg` are on PATH. Quick check:

```bash
AMDuProfCLI info                                        # system/CPU info
AMDuProfCLI collect --config tbp -o /tmp/uprof ./myapp  # sample a binary
AMDuProfCLI report  -i /tmp/uprof/AMDuProf-*            # text report
```

No `msr` kernel-module changes are needed for user-space profiling on the default NixOS sysctls. If a specific counter errors with "Permission denied", run that single invocation with `sudo` -- CAP_SYS_ADMIN bypasses the default paranoid level. If the wrapper complains about a missing `.so`, add the library to `fhsDeps` in the overlay and rebuild.

### Instruction Based Sampling (IBS) and `perf_event_paranoid`

IBS profile scopes require `kernel.perf_event_paranoid <= 1` for non-root users. NixOS defaults to `2`, so `AMDuProfCLI collect` with an IBS config fails with:

```
ERROR: For non-root users, following perf_event_paranoid values are valid
for Instruction Based Sampling:
        <= 1 : for all Instruction Based Sampling profile scopes.
```

Temporary (resets on reboot):

```bash
sudo sysctl -w kernel.perf_event_paranoid=1
```

Persistent, add to `nixos/configuration.nix`:

```nix
boot.kernel.sysctl."kernel.perf_event_paranoid" = 1;
```

Check the current value with `cat /proc/sys/kernel/perf_event_paranoid`. Alternatively, run `AMDuProfCLI collect` under `sudo` -- root bypasses the paranoid check entirely.

## NVIDIA Nsight Graphics (optional)

Nsight Graphics isn't in nixpkgs (only `nsight_compute` and `nsight_systems` are). NVIDIA gates the download behind a developer login, so no fetchurl is possible. The overlay at `nixos/overlays/nsight-graphics.nix` handles it via `requireFile`: it extracts the Makeself installer's `pkg/` tree and wraps the headless CLI in a `buildFHSEnv`. The GUI (`ngfx-ui`) is intentionally skipped.

Gated by `nsightGraphics` in `host.nix`. Leave it `false` (default) and `install.sh` works on any machine without the installer.

### One-time setup

```bash
# 1. Download NVIDIA_Nsight_Graphics_<version>-linux_x64.run (~450 MB) from:
#      https://developer.nvidia.com/nsight-graphics
#    (The version pinned in the overlay is 2026.2.0.26134 -- bump
#     `nsightVersion` there if you grab a newer release.)

# 2. Compute its hash and paste into `nsightHash` in
#    nixos/overlays/nsight-graphics.nix:
nix hash file ~/Downloads/NVIDIA_Nsight_Graphics_2026.2.0.26134-linux_x64.run

# 3. Add the installer to the Nix store:
nix store add-file ~/Downloads/NVIDIA_Nsight_Graphics_2026.2.0.26134-linux_x64.run

# 4. Enable the flag in nixos/host.nix:
#      nsightGraphics = true;

# 5. Rebuild
./install.sh
```

Afterwards `ngfx`, `ngfx-capture`, and `ngfx-replay` are on PATH. Quick check:

```bash
ngfx --version                        # tool version
ngfx --help-all                       # general + per-activity options
ngfx --activity "GPU Trace Profiler" --exe ./myapp --output-dir /tmp/trace
```

The NVIDIA driver libraries reach the sandbox through `/run/opengl-driver`, which `buildFHSEnv` mounts automatically. If the wrapper complains about a missing `.so`, add the library to `fhsDeps` in the overlay and rebuild.

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

## AI Tools

The CLI tools and official Linux desktop apps install through one script, independently of NixOS rebuilds. Commands go in `~/.local/bin` (already on PATH via home-manager):

```bash
./scripts/install-ai-tools.sh                 # install/update all four
./scripts/install-ai-tools.sh cli             # Claude Code + Codex CLIs
./scripts/install-ai-tools.sh gui             # ChatGPT + Claude desktop apps
./scripts/install-ai-tools.sh codex           # just the Codex CLI
./scripts/install-ai-tools.sh claude          # just the Claude Code CLI
./scripts/install-ai-tools.sh chatgpt         # just ChatGPT Desktop
./scripts/install-ai-tools.sh claude-desktop  # just Claude Desktop
```

claude-code uses Anthropic's official installer and self-updates afterwards. codex installs from npm (`@openai/codex`, vendors static musl binaries that run on NixOS unpatched) with `--prefix ~/.local`; rerun the script to update it. The script also copies and pins the managed Codex app-server daemon to the installed CLI package, even when the CLI is already current, then prints both versions. Updating the daemon can interrupt active Codex sessions; run the script from a separate terminal when ready to reconnect.

The desktop installer selects the newest version from [OpenAI's Linux repository](https://learn.chatgpt.com/docs/linux/linux-app) and [Anthropic's Linux repository](https://support.claude.com/en/articles/10065433-install-claude-desktop), checks the download against the repository's SHA-256, and extracts the official `.deb` into `~/.local/share/ai-tools/`. It creates application-menu entries and the `chatgpt` and `claude-desktop` commands. `XDG_DATA_HOME` is honored. Close the app before updating; rerun the script to update it. The previous release is retained, and a failed download or extraction leaves the current app in place. No sudo, apt installation, flake input, or system rebuild is involved.

On NixOS, the desktop launcher uses this configuration's existing `nix-ld`, Brave, and Seahorse installations for the loader and Chromium/GTK/keyring libraries. It resolves their current library paths at launch, so system upgrades do not leave hardcoded store paths behind. `curl`, `ar`, `tar` (with xz/zstd support), Python 3, and `flock` are installer prerequisites already supplied by this configuration. The desktop installer also accepts Linux ARM64 on other distributions; this repo's NixOS configuration targets x86_64.

The NixOS launcher explicitly selects GNOME Keyring (`--password-store=gnome-libsecret`), because Electron does not automatically recognize Hyprland's keyring backend. It selects native Wayland when `NIXOS_OZONE_WL=1` and `WAYLAND_DISPLAY` are set. When `TMPDIR` is unset or `/tmp`, the launcher supplies a private directory under `~/.cache/ai-tools/` for temporary files that honor `TMPDIR`; upstream components may still use hardcoded `/tmp` paths. Custom launch arguments and a custom `TMPDIR` are preserved.

This installs the GUI applications; Claude Cowork's local virtual machine still needs KVM access, QEMU, firmware, and virtiofsd. The installer does not configure those host services or Debian-specific firmware paths. Desktop features remain subject to upstream Linux preview/beta support and your account plan.

The nightly update check (`nixos/update-check.nix`) is **enabled by default** (`updateCheck = true` in `host.nix`). It fetches `origin/main` and notifies you (shell login + desktop notification) if your local branch is behind. It never pulls commits, changes `flake.lock`, rebuilds, or activates NixOS. Review and apply upstream changes manually when you are ready. Set `updateCheck = false` to disable it.

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
