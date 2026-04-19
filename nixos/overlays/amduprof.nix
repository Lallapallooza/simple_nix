# AMD uProf -- microarchitectural profiler for Zen CPUs (IBS, PMU counters,
# cache/memory/branch/TLB/power events, timechart).
#
# Not in nixpkgs. AMD gates downloads behind a EULA form -- no stable URL
# we can fetchurl, every packaging system (AUR, Spack, EasyBuild) hits the
# same wall. So the tarball is supplied via requireFile.
#
# --- One-time setup (per host) -----------------------------------------
#   1. Download from https://www.amd.com/en/developer/uprof.html
#      File: AMDuProf_Linux_x64_<version>.tar.bz2  (~300 MB)
#
#   2. Compute its hash and paste into `uprofHash` below:
#        nix hash file ~/Downloads/AMDuProf_Linux_x64_<version>.tar.bz2
#
#   3. Add the tarball to the Nix store:
#        nix store add-file ~/Downloads/AMDuProf_Linux_x64_<version>.tar.bz2
#
#   4. Enable in host.nix:  amduprof = true;
#
#   5. ./install.sh
#
# Default `amduprof = false` means install.sh succeeds on any host without
# the tarball -- the overlay's derivations are defined but never built.

final: prev:

let
  uprofVersion = "5.2.606";
  uprofTarball = "AMDuProf_Linux_x64_${uprofVersion}.tar.bz2";
  uprofHash    = "sha256-1YVqZkD2xnOUHctuQvcrWJ1la6QNK6A/8SFWEbKDDxE=";

  src = prev.requireFile {
    name = uprofTarball;
    hash = uprofHash;
    message = ''
      AMD uProf tarball not in Nix store. One-time setup:

        nix hash file ~/Downloads/${uprofTarball}
        # paste the printed sha256-... into `uprofHash` in
        # nixos/overlays/amduprof.nix, then:
        nix store add-file ~/Downloads/${uprofTarball}
        sudo nixos-rebuild switch
    '';
  };

  # Raw tree. Binaries link via $ORIGIN/../lib/x64, so preserve layout.
  # unpackPhase auto-chdirs into ${uprofTopDir}, so CWD *is* that dir here.
  amduprof-unwrapped = prev.stdenvNoCC.mkDerivation {
    pname = "amduprof-unwrapped";
    version = uprofVersion;
    inherit src;

    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;    # Stripping breaks the shipped .so files.

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -a . $out/
      runHook postInstall
    '';

    meta = with prev.lib; {
      description = "AMD uProf -- raw tree (wrap via buildFHSEnv for use)";
      homepage = "https://www.amd.com/en/developer/uprof.html";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };

  # Runtime libs needed by the shipped ELF binaries. Derived by running
  # `ldd` across every binary + .so in the tarball and mapping missing
  # entries to nixpkgs packages. uProf's CLI transitively links Qt5/X11
  # even when headless, so the X/xcb surface is required.
  #
  # GPU-profiling plugins dlopen libhsa-runtime64.so.1, librocprofiler64,
  # libroctracer64. These are NOT needed for CPU profiling -- add ROCm
  # packages here only when you actually want to profile an AMD GPU.
  fhsDeps = p: with p; [
    amduprof-unwrapped

    # Core
    glibc
    stdenv.cc.cc.lib           # libstdc++.so.6
    zlib zstd                  # libz.so.1, libzstd.so.1
    elfutils                   # libelf.so.1, libdw.so
    ncurses                    # libtinfo.so.6
    libxcrypt libxcrypt-legacy # libcrypt.so.1

    # Desktop / IPC
    dbus                       # libdbus-1.so.3
    glib                       # libglib-2.0.so.0, libgthread-2.0.so.0
    fontconfig freetype        # Qt pulls these in even headless

    # OpenGL / EGL (libglvnd bundles GL/EGL under one package)
    libGL libGLU               # libGL.so.1, libGLU.so.1, libEGL.so.1

    # xkbcommon
    libxkbcommon               # libxkbcommon.so.0 + libxkbcommon-x11.so.0

    # X11 / XCB -- required by bundled Qt5 libs
    libx11                     # libX11.so.6, libX11-xcb.so.1
    libxext libxi libxmu
    libxcb                     # libxcb + xcb-{glx,randr,render,shape,shm,sync,xfixes,xinerama,xkb}
    libxcb-util
    libxcb-image               # libxcb-image.so.0
    libxcb-keysyms             # libxcb-keysyms.so.1
    libxcb-render-util         # libxcb-render-util.so.0
    libxcb-wm                  # libxcb-icccm.so.4
  ];

  # libtinfo.so.5 (some helper tools still link against the old ABI) --
  # nixpkgs only ships v6 in `ncurses`. Symlink inside the FHS rootfs.
  uprofFhsExtraCommands = ''
    ln -sfn libtinfo.so.6 $out/usr/lib/libtinfo.so.5 || true
    ln -sfn libtinfo.so.6 $out/usr/lib64/libtinfo.so.5 || true
  '';

  wrapUprof = bin: prev.buildFHSEnv {
    name = bin;
    targetPkgs = fhsDeps;
    extraBuildCommands = uprofFhsExtraCommands;
    # uProf's own .so tree lives at $ORIGIN; binaries also dlopen helpers
    # from lib/x64/shared. Export LD_LIBRARY_PATH so plugin loads resolve.
    runScript = prev.writeShellScript "${bin}-run" ''
      export LD_LIBRARY_PATH=${amduprof-unwrapped}/bin:${amduprof-unwrapped}/lib/x64/shared''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
      exec ${amduprof-unwrapped}/bin/${bin} "$@"
    '';
    meta = {
      description = "AMD uProf ${bin} (FHS-wrapped)";
      license = prev.lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
      mainProgram = bin;
    };
  };

in {
  amduprof     = wrapUprof "AMDuProfCLI";
  amduprof-pcm = wrapUprof "AMDuProfPcm";
  amduprof-cfg = wrapUprof "AMDuProfCfg";
  inherit amduprof-unwrapped;
}
