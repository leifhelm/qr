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

              qrencode
              texliveFull
              ghostscript_headless
              typst
              tinymist

              qqwing
              pkgsCross.aarch64-multiplatform.pkgsBuildTarget.gcc
            ]
            ++ (with llvmPackages_18; [
              bintools
              clang
              lld
            ])
            ++ (with python3Packages; [ lxml ])
            ++ lib.optionals (system == "x86_64-linux") [ elfuck ];
          };
      }
    );
}
