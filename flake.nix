{
  inputs = {
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
    cargo-script-mvs = {
      url = "github:epage/cargo-script-mvs";
      flake = false;
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.follows = "rust-overlay/nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = {
    self,
    advisory-db,
    cargo-script-mvs,
    crane,
    flake-utils,
    nixpkgs,
    rust-overlay,
  }: let
    rustChannel = "beta";
    rustVersion = "latest";
    rustToolchain = pkgs:
      pkgs.rust-bin.${rustChannel}.${rustVersion}.default;
  in
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
      };
      devShellPackages = [
        (rustToolchain pkgs)
        pkgs.bacon
        pkgs.cargo-eval
      ];
    in {
      checks = removeAttrs pkgs.cargo-eval-crate.checks [
        "my-crate-audit"
      ];

      devShells.default = pkgs.mkShell {
        packages = devShellPackages;
        shellHook = ''
          # temporarily enable sparse-index, until stabilized (in rust 1.70?)
          export CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse
        '';
      };

      packages = {
        default = pkgs.cargo-eval;
        script = pkgs.writeRustScriptBin "script" ''
          //! ```cargo
          //! [dependencies]
          //! rand = "0.8"
          //! ```
          fn main() {
            println!("your lucky number is {}", rand::random::<u16>());

            let mut args = std::env::args();
            if let Some(first) = args.next() {
              println!("\ncheck out the built binary location:");
              println!("\t{first}");
            }
          }
        '';
      };
    })
    // {
      overlays = {
        rust-overlay = rust-overlay.overlays.default;

        cargo-eval = final: prev: let
          craneLib = (crane.mkLib final).overrideToolchain (rustToolchain final);
          crate = final.callPackage ./crate.nix {
            inherit advisory-db craneLib;
            srcDir = cargo-script-mvs;
          };
        in {
          cargo-eval = crate.package;
          cargo-eval-crate = crate;
        };

        writeRustScriptBin = final: prev: {
          writeRustScriptBin = name: text: let
            name-src = "${name}-src";
            script-src = final.writeScriptBin name-src ''
              #!${final.cargo-eval}/bin/cargo-eval
              ${text}'';
            script-run = final.writeShellScriptBin name ''
              export PATH=${final.lib.strings.makeSearchPath "bin" [
                final.gcc
                (rustToolchain final)
              ]}
              ${script-src}/bin/${name-src}
            '';
          in
            final.symlinkJoin {
              inherit name;
              paths = [
                script-src
                script-run
              ];
            };
        };

        default = final: prev:
          (self.overlays.rust-overlay final prev)
          // (self.overlays.cargo-eval final prev)
          // (self.overlays.writeRustScriptBin final prev);
      };
    };
}
