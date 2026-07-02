{ pkgs ? import <nixpkgs> { } }:

# Development shell for building ZMK firmware locally (e.g. Corne / nice!nano).
#
# ZMK is built on top of Zephyr RTOS and uses the `west` meta-tool together
# with the ARM embedded (arm-none-eabi) toolchain. This shell provides all of
# the native build dependencies through Nix and installs the Python tooling
# (west + Zephyr requirements) into a local virtualenv on first launch.
#
# Usage:
#   nix-shell
#
# Then, the first time (or after updating west.yml):
#   west init -l config           # if you have a config/ manifest
#   west update
#   west zephyr-export
#
# Build (Corne, nice!nano v2, left/right halves):
#   west build -s zmk/app -b nice_nano_v2 -- -DSHIELD=corne_left
#   west build -s zmk/app -b nice_nano_v2 -- -DSHIELD=corne_right

let
  # Python environment with the packages Zephyr/ZMK expect to be available.
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    west
    pyelftools
    pyyaml
    pykwalify
    canopen
    packaging
    progress
    psutil
    anytree
    intelhex
    unidiff
    setuptools
    wheel
    pip

    # Required for ZMK Studio builds (nanopb / protobuf code generation)
    protobuf
    grpcio-tools
  ]);
in
pkgs.mkShell {
  name = "zmk-shell";

  # Native build tools required by the Zephyr build system.
  nativeBuildInputs = with pkgs; [
    pythonEnv

    # Zephyr / ZMK build toolchain
    cmake
    ninja
    ccache
    dtc                # device tree compiler
    gperf
    git
    wget
    which

    # ARM embedded toolchain (targets the nRF52840 on wireless Corne boards)
    gcc-arm-embedded

    # Handy extras
    dfu-util           # flashing over USB DFU
    gawk
  ];

  # Point Zephyr at the Nix-provided ARM toolchain instead of the Zephyr SDK.
  ZEPHYR_TOOLCHAIN_VARIANT = "gnuarmemb";
  GNUARMEMB_TOOLCHAIN_PATH = "${pkgs.gcc-arm-embedded}";

  # During a ZMK Studio build, `west` prepends its *base* Python interpreter
  # (plain pkgs.python3, without our extra packages) to PATH. The nanopb
  # `protoc` script then runs under that bare interpreter via `#!/usr/bin/env
  # python3` and fails to import `pkg_resources`/`protobuf`/`grpcio-tools`.
  # Exposing the withPackages site-packages via PYTHONPATH lets that bare
  # (ABI-compatible) interpreter import them.
  PYTHONPATH = "${pythonEnv}/${pythonEnv.sitePackages}";

  shellHook = ''
    echo "ZMK development shell"
    echo "  arm-none-eabi-gcc: $(command -v arm-none-eabi-gcc)"
    echo "  west:              $(command -v west)"
    echo "  cmake:             $(cmake --version | head -n1)"
    echo ""
    echo "Toolchain: ZEPHYR_TOOLCHAIN_VARIANT=$ZEPHYR_TOOLCHAIN_VARIANT"
    echo ""
    echo "Next steps:"
    echo "  west init -l config   # initialize the manifest (first time only)"
    echo "  west update           # fetch Zephyr + modules"
    echo "  west zephyr-export"
    echo "  west build -s zmk/app -b nice_nano_v2 -- -DSHIELD=corne_left"
  '';
}
