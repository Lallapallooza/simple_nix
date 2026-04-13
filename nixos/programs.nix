{ lib, pkgs, agenix, host, ... }:

{
  # --- Development ---
  programs.direnv.enable = true;        # Auto-load .envrc per-directory environments
  programs.git.lfs.enable = true;       # Git Large File Storage for binaries (images, etc.)
  programs.nix-ld.enable = true;        # Dynamic linker for non-Nix binaries (Mason, uv, pip wheels)

  # --- Gaming ---
  programs.gamemode.enable = true;      # CPU governor + scheduler optimization while gaming
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;     # Steam Deck-like session selectable at SDDM login
    extraCompatPackages = [ pkgs.proton-ge-bin ];   # Proton-GE for better game compatibility
    package = pkgs.steam.override {
      extraEnv = {
        STEAM_FORCE_DESKTOPUI_SCALING = host.steamScaling;
      };
    };
  };

  # --- Services ---
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };
  virtualisation.podman.enable = true;
  services.flatpak.enable = true;       # Flatpak for apps that need it (e.g. Discord with Krisp)
  services.printing = {
    enable = true;
    browsing = false;                  # Don't advertise printers on the network
  };

  # --- System Packages ---
  environment.systemPackages = with pkgs; [
    # Core utilities
    git git-lfs gh wget curl unzip p7zip file fastfetch optipng
    imagemagick                # Image conversion/resizing (convert, mogrify)
    ffmpeg                     # Audio/video transcoding and processing
    age                        # age encryption (used by agenix for key management)
    agenix.packages.${pkgs.stdenv.hostPlatform.system}.default   # age secret management CLI

    # Modern CLI replacements & tools
    bat                        # cat alternative (syntax highlighting, git integration)
    cloc                       # count lines of code by language
    duf                        # df alternative (disk usage with colors)
    fd                         # find alternative
    ripgrep                    # grep alternative
    fzf                        # Fuzzy finder (used by shell, nvim, etc.)
    delta                      # Better git diffs
    jq                         # JSON processor
    htop                       # Process viewer
    tree                       # Directory listing as tree
    psmisc                     # killall, pstree
    procps                     # pgrep, pkill, ps
    tmux                       # Terminal multiplexer
    mc                         # Midnight Commander file manager
    ntfs3g                     # NTFS filesystem support
  ] ++ lib.optionals host.nvidia [
    nvtopPackages.nvidia       # GPU process monitoring
  ] ++ [
    zstd                       # Fast compression (used by kernel, packing, etc.)
    yq-go                      # jq for YAML/TOML files
    just                       # Modern make alternative for project commands

    # Terminal & editors
    kitty neovim kdePackages.kate

    # Python
    python3 uv ruff

    # Rust
    rustc cargo rust-analyzer

    # Go
    go gopls

    # JVM
    jdk kotlin kotlin-language-server

    # C/C++ / CUDA
    gnumake cmake clang
    clang-tools                # clangd LSP
    tree-sitter                # Treesitter CLI (nvim-treesitter parser compilation)
    cudaPackages_12_8.cudatoolkit   # Pinned for Blackwell sm_120 -- bump when nixpkgs ships 12.9+
    cudaPackages_12_8.cudnn         # cuDNN (GPU-accelerated deep learning primitives)

    # Node/TypeScript
    nodejs typescript bun

    # Profiling & tracing (CPU, memory, dynamic tracing across C++/Rust/Python)
    perf                       # Linux sampling profiler (foundation)
    flamegraph                 # Brendan Gregg's flame graph scripts
    pprof                      # Cross-language pprof-format profile viewer
    graphviz                   # DOT graph renderer (pprof graphs, general use)
    hyperfine                  # CLI benchmarking (--export-json)
    samply                     # Modern sampling profiler -> Firefox Profiler
    hotspot                    # GUI for perf data
    cargo-flamegraph           # `cargo flamegraph` convenience for Rust
    heaptrack                  # Heap profiler for C/C++/Rust (fast, text report)
    valgrind                   # memcheck/massif/callgrind/cachegrind
    py-spy                     # Python sampling profiler, attach-to-running
    memray                     # Python memory profiler (Bloomberg)
    scalene                    # Python CPU+memory+GPU, Python vs native split
    bpftrace                   # eBPF dynamic tracing (JSON output)
    uftrace                    # Function-graph tracer (C/C++/Rust)

    # AI coding tools
    claude-code gemini-cli codex opencode rtk glow beads

    # LSP servers (for neovim)
    bash-language-server
    typescript-language-server
    cmake-language-server
    basedpyright               # Python LSP (pyright fork with better type inference)
    nixd                       # Nix LSP (eval-based completions, option lookups)

    # Formatters & linters (for neovim via conform.nvim)
    stylua                     # Lua
    rustfmt                    # Rust
    gotools                    # Go (goimports)
    prettier                   # TypeScript/JavaScript
    codespell                  # Spell checker for code
    pre-commit                 # Git pre-commit hook framework

    # Desktop apps
    brave vscode vlc spotify telegram-desktop slack yt-dlp qbittorrent
    mangohud                   # Real-time FPS/GPU/CPU overlay for games

    # VPN
    wireguard-tools            # WireGuard CLI (kernel module built-in; NM handles GUI)
    openvpn                    # OpenVPN tunnel client
    networkmanager-openvpn     # OpenVPN plugin for NetworkManager GUI
    v2ray                      # Proxy platform for bypassing network restrictions
    ivpn                       # IVPN daemon
    ivpn-ui                    # IVPN desktop GUI

    # Qt Wayland -- needed for native Wayland rendering in Qt apps (Dolphin, KDE tools)
    qt5.qtwayland qt6.qtwayland

    # Hyprland ecosystem
    hyprpanel                  # Status bar
    rofi                       # App launcher + window switcher
    hyprpaper                  # Wallpaper daemon
    hyprlock                   # Lock screen
    hypridle                   # Idle management (triggers lock/suspend)
    wl-clipboard               # Wayland clipboard (wl-copy/wl-paste)
    grimblast                  # Screenshot helper (wraps grim+slurp+wl-copy)
    grim                       # Screenshot capture
    slurp                      # Region selection for screenshots

    # Theming (GTK theme + icons managed by home-manager in theming.nix)

    # Desktop utilities
    imv                        # Fast Wayland-native image viewer
    file-roller                # Archive manager GUI (zip/tar/7z)
    mission-center             # System monitor (CPU/GPU/RAM/disk, GTK4 Wayland native)

    # Desktop services
    lxqt.lxqt-policykit       # Polkit authentication agent (GUI sudo prompts)
    libnotify                  # Desktop notifications (notify-send)
    networkmanagerapplet       # Network manager tray icon
    pavucontrol                # PulseAudio/PipeWire volume control GUI
    brightnessctl              # Screen brightness control
    playerctl                  # MPRIS media player control (play/pause/next)
    seahorse                   # GUI for managing gnome-keyring passwords
    wdisplays                  # Wayland display/monitor configuration GUI
  ];
}
