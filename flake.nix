{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        elfuck = pkgs.pkgsi686Linux.callPackage (
          { stdenv, fetchFromGitHub }:
          stdenv.mkDerivation {
            pname = "elfuck";
            version = "0.1";
            src = fetchFromGitHub {
              owner = "timhsutw";
              repo = "elfuck";
              rev = "5e60852b1fc2f1b5eb5d8834152eeffd0f8b3597";
              hash = "sha256-/ZNnuqb9pO+GQcWXSK5lrQY9AcLAMuHWFnFk5Q6yq3c=";
            };
            installPhase = ''
              mkdir -p $out/bin
              cp src/elfuck $out/bin
            '';
          }
        ) { };
        python = pkgs.python3.override {
          self = python;
          packageOverrides = pyfinal: pyprev: {
            pydeflate = pyfinal.callPackage (
              {
                stdenv,
                fetchFromGitHub,
                buildPythonPackage,
                setuptools,
              }:
              buildPythonPackage {
                pname = "pydeflate";
                version = "0.1.0-e0061df";
                src = fetchFromGitHub {
                  owner = "Nowam";
                  repo = "pydeflate";
                  rev = "e0061df5790a2cdd4b424cccc1033104272e3a02";
                  hash = "sha256-BQu/YkNVnqOlRcKbVVjnWM64Xk57I0x3cV9LPCCJk1o=";
                };
                pyproject = true;
                build-system = [ setuptools ];
              }
            ) { };
          };
        };
        x86_64-linux = import nixpkgs {
          crossSystem = {
            config = "x86_64-unknown-linux-gnu";
          };
          inherit system;
        };
        i686-linux = import nixpkgs {
          crossSystem = {
            config = "i686-unknown-linux-gnu";
          };
          inherit system;
        };
      in
      {
        devShells.default =
          with pkgs;
          stdenvNoCC.mkDerivation {
            name = "dev-shell";
            version = "1.0.0";
            buildInputs = [
              gdb
              nasm
              gnumake

              qrencode
              texliveFull
              ghostscript_headless
              typst
              tinymist

              qqwing
              pkgsCross.aarch64-multiplatform.pkgsBuildTarget.gcc
              i686-linux.pkgsBuildTarget.binutils
              x86_64-linux.pkgsBuildTarget.binutils
              (python.withPackages (
                python-pkgs: with python-pkgs; [
                  lxml
                  segno
                  pydeflate
                  qrcode
                ]
              ))
            ]
            ++ (with llvmPackages_18; [
              bintools
              clang
              lld
            ])
            ++ lib.optionals (system == "x86_64-linux") [ elfuck ];
          };
      }
    );
}
