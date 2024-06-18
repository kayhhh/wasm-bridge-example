{
  inputs = {
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      crane,
      flake-utils,
      rust-overlay,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      localSystem:
      let
        pkgs = import nixpkgs {
          inherit localSystem;
          overlays = [ (import rust-overlay) ];
        };

        rustToolchain = pkgs.pkgsBuildHost.rust-bin.stable.latest.default.override {
          targets = [ "wasm32-wasi" ];
        };

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        commonArgs = {
          src = pkgs.lib.cleanSourceWith {
            src = ./.;
            filter =
              path: type:
              (pkgs.lib.hasSuffix ".html" path)
              || (pkgs.lib.hasSuffix ".wit" path)
              || (craneLib.filterCargoSources path type);
          };
          strictDeps = true;
        };

        cargoArtifacts = craneLib.buildDepsOnly (commonArgs // { pname = "deps"; });

        cargoClippy = craneLib.cargoClippy (
          commonArgs
          // {
            inherit cargoArtifacts;
            pname = "clippy";
          }
        );

        cargoDoc = craneLib.cargoDoc (
          commonArgs
          // {
            inherit cargoArtifacts;
            pname = "doc";
          }
        );

        guest = craneLib.buildPackage (
          commonArgs
          // rec {
            pname = "guest";

            src = pkgs.lib.cleanSourceWith {
              src = ./.;
              filter = path: type: (pkgs.lib.hasSuffix ".wit" path) || (craneLib.filterCargoSources path type);
            };

            nativeBuildInputs = with pkgs; [ cargo-component ];

            cargoBuildCommand = "cargo component build";
            cargoExtraArgs = "--locked -p ${pname}";
            doCheck = false;
            strictDeps = true;
          }
        );

        host = craneLib.buildPackage (
          commonArgs
          // {
            inherit cargoArtifacts;
            pname = "host";
            cargoExtraArgs = "--locked -p host";
            preBuild =
              let
                out = "target/wasm32-wasi/debug";
              in
              ''
                mkdir -p ${out}
                cp ${guest}/lib/guest.wasm ${out}
              '';
          }
        );

        host-web = craneLib.buildTrunkPackage (
          commonArgs
          // {
            pname = "host-web";
            cargoExtraArgs = "--locked -p host";
            wasm-bindgen-cli = pkgs.wasm-bindgen-cli;
            preBuild =
              let
                out = "target/wasm32-wasi/debug";
              in
              ''
                mkdir -p ${out}
                cp ${guest}/lib/guest.wasm ${out}
              '';
          }
        );
      in
      {
        checks = {
          inherit
            cargoClippy
            cargoDoc
            guest
            host
            host-web
            ;
        };

        packages = {
          inherit guest host host-web;
        };

        devShells.default = craneLib.devShell {
          checks = self.checks.${localSystem};
          packages = with pkgs; [
            cargo-component
            cargo-watch
            nodePackages.prettier
            rust-analyzer
            trunk
          ];
        };
      }
    );
}
