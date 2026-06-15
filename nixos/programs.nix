{ config, lib, pkgs, agenix, host, bv, ... }:

let
  mathLibs = with pkgs; [ blis openblas fftw gsl suitesparse eigen llvmPackages_latest.openmp ];
  # Non-Nix desktop/game binaries dlopen these at runtime (via nix-ld):
  # Wayland + xkbcommon (display/input), Vulkan + libglvnd (GPU loaders), alsa-lib (audio), udev (devices).
  desktopRuntimeLibs = with pkgs; [ alsa-lib wayland libxkbcommon udev vulkan-loader libglvnd ];
  # wgpu-utils also ships parsers, examples, xtask helpers and a bug-repro that
  # would clutter PATH. Expose only the two general-purpose CLIs. wgpu-info's
  # wrapper references its target by absolute store path, so symlinks suffice.
  nagaTools = pkgs.runCommand "naga-${pkgs.wgpu-utils.version}" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.wgpu-utils}/bin/naga $out/bin/naga
    ln -s ${pkgs.wgpu-utils}/bin/wgpu-info $out/bin/wgpu-info
  '';
in

{
  # --- Development ---
  programs.direnv.enable = true;        # Auto-load .envrc per-directory environments
  programs.nix-ld.enable = true;        # Dynamic linker for non-Nix binaries (Mason, uv, pip wheels)
  programs.nix-ld.libraries = desktopRuntimeLibs;

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
  # Rootless Docker can't resolve DNS because NixOS's resolv.conf symlink chain
  # goes through /nix/store, which slirp4netns sandboxes away.
  # For VPN-internal hostnames (e.g. private mirrors), use --network host.
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
    daemon.settings.dns = [ "1.1.1.1" "8.8.8.8" ];
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
    git-filter-repo gh wget curl unzip p7zip file fastfetch optipng
    imagemagick                # Image conversion/resizing (convert, mogrify)
    poppler-utils              # PDF utilities (pdftotext, pdfimages, pdfinfo)
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
    efibootmgr                 # Manage UEFI NVRAM boot entries
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
    rustc cargo rust-analyzer cargo-nextest

    # Go
    go gopls

    # JVM
    jdk kotlin kotlin-language-server

    # C/C++ / CUDA
    gnumake cmake ninja gcc clang
    clang-tools                # clangd LSP
    llvmPackages_latest.llvm   # LLVM tools (opt, llvm-ar, llvm-nm, etc.)
    llvmPackages_latest.lld    # LLVM linker
    llvmPackages_latest.lldb   # LLVM debugger
    pkg-config                 # Library metadata resolver (used by cmake/autotools/cargo)
    sccache                    # Compiler cache for C/C++/CUDA (via CMake launcher). Skipped for Rust -- conflicts with incremental compilation.
    mold                       # Fast parallel linker; opt-in per-project via -fuse-ld=mold or .cargo/config.toml
    conan                      # C/C++ package manager
    vcpkg                      # Microsoft C/C++ package manager
    vcpkg-tool                 # vcpkg standalone tool
    doxygen                    # API doc generator (uses graphviz for call/dep graphs)
    tree-sitter                # Treesitter CLI (nvim-treesitter parser compilation)
    cudaPackages_13_2.cudatoolkit     # CUDA 13.2 -- Blackwell sm_120 supported, driver >=580 required
    cudaPackages_13_2.cudnn           # cuDNN (GPU-accelerated deep learning primitives)
    cudaPackages_13_2.nsight_compute  # ncu -- kernel-level GPU profiler
    cudaPackages_13_2.nsight_systems  # nsys -- system-wide GPU/CPU timeline profiler
    cudaPackages_13_2.cuda_nsight     # nsight -- Eclipse-based CUDA IDE/debugger

    # Numerical / math libraries (CPU)
    blis                       # BLAS tuned for Zen (matches/beats MKL on Ryzen)
    openblas                   # BLAS + LAPACK (bundles cblas.h/libcblas, lapacke)
    fftw                       # FFT (double precision)
    eigen                      # Header-only C++ linear algebra
    gsl                        # GNU Scientific Library
    suitesparse                # Sparse linear algebra (UMFPACK, CHOLMOD, etc.)

    # Node/TypeScript
    nodejs typescript bun

    # Cloud tools
    awscli2                    # AWS CLI v2

    # Graphics & shader tooling
    renderdoc                  # Frame debugger/profiler (Vulkan/OpenGL/GLES)
    vulkan-tools               # vulkaninfo, vkcube -- enumerate ICDs/devices, smoke-test rendering
    vulkan-tools-lunarg        # vkconfig -- toggle Vulkan layers and settings
    vulkan-validation-layers   # VK_LAYER_KHRONOS_validation -- catch API misuse at runtime
    vulkan-extension-layer     # Emulate optional Vulkan extensions for testing
    spirv-tools                # spirv-as/dis/val/opt/link -- assemble, validate, optimize SPIR-V
    spirv-cross                # Translate SPIR-V back to GLSL/HLSL/MSL, plus reflection
    glslang                    # glslangValidator -- reference GLSL/HLSL to SPIR-V compiler
    shaderc                    # glslc -- GLSL/HLSL to SPIR-V compiler (Google)
    shader-slang               # slangc -- Khronos Slang shading language compiler
    directx-shader-compiler    # dxc -- HLSL to SPIR-V/DXIL
    nagaTools                  # naga + wgpu-info from wgpu-utils (gfx-rs/wgpu shader translator + adapter probe)

    # Profiling & tracing (CPU, memory, dynamic tracing across C++/Rust/Python)
    perf                       # Linux sampling profiler (foundation)
    flamegraph                 # Brendan Gregg's flame graph scripts
    pprof                      # Cross-language pprof-format profile viewer
    graphviz                   # DOT graph renderer (pprof graphs, general use)
    d2                         # Declarative diagram scripting language (terrastruct)
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
    bcc                        # BCC toolkit: offcputime, profile, execsnoop, etc.
    uftrace                    # Function-graph tracer (C/C++/Rust)
    likwid                     # Zen PMU counters: cache/mem/FLOPS/AVX, topology-aware
    hwloc                      # Hardware topology (lstopo, hwloc-bind, hwloc-info)
    config.boot.kernelPackages.cpupower   # CPU frequency/governor control (kernel-matched)
  ] ++ lib.optionals (host.amduprof or false) [
    amduprof                   # AMD uProf CLI (Zen microarch + IBS + timechart)
    amduprof-pcm               # AMD uProf per-core memory/cache counters
  ] ++ [

    # AI coding tools
    claude-code codex opencode glow
    br bv                      # Rust port of beads (overlay) + Go TUI viewer (flake input)

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
    (if host.nvidia then blender.override { cudaSupport = true; } else blender)   # 3D suite; Cycles GPU rendering via OptiX/CUDA on nvidia
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
  ] ++ (map lib.getDev (mathLibs ++ desktopRuntimeLibs));

  # Math libs go on CPATH + LIBRARY_PATH + pkg-config so raw `gcc -lblas` works.
  # Desktop-runtime libs are pkg-config only -- their typical consumers
  # (CMake, meson) resolve them via pkg-config rather than -I/-l flags.
  # Trade-off: these env vars leak into unrelated user-session compilations;
  # switch to a shell.nix per project if that causes surprises.
  environment.variables = {
    CC = "clang";
    CXX = "clang++";
    CPATH = lib.makeSearchPathOutput "dev" "include" mathLibs;
    LIBRARY_PATH = lib.makeLibraryPath mathLibs;
    PKG_CONFIG_PATH = lib.concatStringsSep ":" [
      (lib.makeSearchPathOutput "dev" "lib/pkgconfig" (mathLibs ++ desktopRuntimeLibs))
      (lib.makeSearchPathOutput "dev" "share/pkgconfig" (mathLibs ++ desktopRuntimeLibs))
    ];

    # sccache: route CMake-driven C/C++/CUDA through the cache by default.
    # Rust is intentionally NOT wrapped -- sccache disables Cargo incremental
    # compilation, which usually hurts iterative dev cycles more than caching helps.
    # Raw make/autotools projects are not covered (would need CC="sccache clang",
    # which breaks some configure scripts) -- opt in per-project when needed.
    CMAKE_C_COMPILER_LAUNCHER = "sccache";
    CMAKE_CXX_COMPILER_LAUNCHER = "sccache";
    CMAKE_CUDA_COMPILER_LAUNCHER = "sccache";
    SCCACHE_CACHE_SIZE = "50G";
  };
}
