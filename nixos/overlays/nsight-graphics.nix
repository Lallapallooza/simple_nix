# NVIDIA Nsight Graphics -- frame debugger and GPU profiler for Vulkan/OpenGL/
# DirectX/DXR. This packages the headless CLI only (ngfx, ngfx-capture,
# ngfx-replay); the Qt GUI (ngfx-ui) is intentionally skipped.
#
# Not in nixpkgs. NVIDIA gates downloads behind a developer login -- no stable
# URL to fetchurl. So the .run installer is supplied via requireFile.
#
# The installer is a Makeself self-extractor wrapping a Perl script that copies
# a pkg/ tree to a target path. We extract that tree and run the shipped CLI
# launchers inside a buildFHSEnv: they bundle their own Qt6/ICU/crypto and set
# LD_LIBRARY_PATH to the bundle, so the FHS only needs to supply the system
# libraries the binaries still link (glib, dbus, fontconfig, X11/XCB, GL).
#
# --- One-time setup (per host) -----------------------------------------
#   1. Download from https://developer.nvidia.com/nsight-graphics
#      File: NVIDIA_Nsight_Graphics_<version>-linux_x64.run  (~450 MB)
#
#   2. Compute its hash and paste into `nsightHash` below:
#        nix hash file ~/Downloads/NVIDIA_Nsight_Graphics_<version>-linux_x64.run
#
#   3. Add the installer to the Nix store:
#        nix store add-file ~/Downloads/NVIDIA_Nsight_Graphics_<version>-linux_x64.run
#
#   4. Enable in host.nix:  nsightGraphics = true;
#
#   5. ./install.sh
#
# Default `nsightGraphics = false` means install.sh succeeds on any host
# without the installer -- the overlay's derivations are defined but never built.

final: prev:

let
  nsightVersion = "2026.2.0.26134";
  nsightRun     = "NVIDIA_Nsight_Graphics_${nsightVersion}-linux_x64.run";
  nsightHash    = "sha256-gXwkSUpxpzidd2E7ZZ7/m3KpdHqendcDUQ9J260QoIk=";

  # Where the CLI launchers live inside the extracted pkg/ tree.
  hostDir = "host/linux-desktop-nomad-x64";

  src = prev.requireFile {
    name = nsightRun;
    hash = nsightHash;
    message = ''
      Nsight Graphics installer not in Nix store. One-time setup:

        nix hash file ~/Downloads/${nsightRun}
        # paste the printed sha256-... into `nsightHash` in
        # nixos/overlays/nsight-graphics.nix, then:
        nix store add-file ~/Downloads/${nsightRun}
        sudo nixos-rebuild switch
    '';
  };

  # Raw tree. The Makeself archive runs under our sh (its /bin/sh shebang is
  # ignored when invoked as `sh $src`). --noexec skips the Perl installer;
  # --nochown skips the chown the sandbox build user cannot perform.
  nsight-graphics-unwrapped = prev.stdenvNoCC.mkDerivation {
    pname = "nsight-graphics-unwrapped";
    version = nsightVersion;
    inherit src;

    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;      # Stripping breaks the shipped .so files.
    dontPatchELF = true;   # Leave the vendor ELF rpaths untouched.

    unpackPhase = ''
      runHook preUnpack
      sh "$src" --quiet --noexec --nox11 --noprogress --nochown --keep --target ./extracted
      runHook postUnpack
    '';
    sourceRoot = "extracted";

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -a pkg/. $out/
      runHook postInstall
    '';

    meta = with prev.lib; {
      description = "NVIDIA Nsight Graphics -- raw tree (wrap via buildFHSEnv for use)";
      homepage = "https://developer.nvidia.com/nsight-graphics";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };

  # System libraries the CLI binaries link but do NOT bundle. Derived by
  # running `ldd` across ngfx.bin/ngfx-capture.bin/ngfx-replay.bin with the
  # bundle on LD_LIBRARY_PATH and mapping every "not found" to a nixpkgs
  # package. Qt6Gui links X11/XCB/EGL/GL even under QT_QPA_PLATFORM=offscreen,
  # so the X surface is required despite being headless. The NVIDIA driver
  # itself (libcuda, libnvidia-*) arrives via buildFHSEnv's /run/opengl-driver.
  fhsDeps = p: with p; [
    # Core C/C++ runtime
    glibc
    stdenv.cc.cc.lib           # libstdc++.so.6
    zlib                       # libz.so.1

    # Glib / IPC / fonts -- Qt deps not in the bundle
    glib                       # libglib/gobject/gio/gmodule/gthread-2.0
    dbus                       # libdbus-1.so.3
    fontconfig                 # libfontconfig.so.1
    freetype                   # libfreetype (fontconfig dependency)
    libpng                     # libpng16.so.16

    # OpenGL / EGL loader (libglvnd) -- dispatches to the driver under FHS
    libGL                      # libGL.so.1, libEGL.so.1

    # xkbcommon
    libxkbcommon               # libxkbcommon.so.0

    # X11 / XCB -- linked by Qt6 Gui even when rendering offscreen
    libx11                     # libX11.so.6, libX11-xcb.so.1
    libxcb                     # libxcb + xcb-{glx,randr,render,shape,shm,sync,xfixes,xkb,dri2,dri3,present}
    libxau
    libxdmcp
  ];

  # The launchers (ngfx, ...) are bash scripts that resolve their own bundle
  # path via `readlink -f $0` and set LD_LIBRARY_PATH before exec'ing the .bin.
  # Run them through bash explicitly so the FHS does not depend on /bin/bash.
  wrap = bin: prev.buildFHSEnv {
    name = bin;
    targetPkgs = fhsDeps;
    runScript = prev.writeShellScript "${bin}-run" ''
      # The bundled Qt only ships Windows/Fusion; drop a desktop-wide style
      # override (e.g. breeze) so it does not warn on every invocation.
      unset QT_STYLE_OVERRIDE
      exec bash ${nsight-graphics-unwrapped}/${hostDir}/${bin} "$@"
    '';
    meta = {
      description = "NVIDIA Nsight Graphics ${bin} (FHS-wrapped CLI)";
      license = prev.lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
      mainProgram = bin;
    };
  };

in {
  ngfx         = wrap "ngfx";
  ngfx-capture = wrap "ngfx-capture";
  ngfx-replay  = wrap "ngfx-replay";
  inherit nsight-graphics-unwrapped;
}
