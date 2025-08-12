{
  description = "Jir";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
        let
          pkgs = nixpkgs.legacyPackages."${system}";
          jir = pkgs.callPackage ./default.nix {};
        in {
          packages = { inherit jir; };
          apps =
            let
              appFor = name: drv: flake-utils.lib.mkApp {
                inherit name drv;
              };
            in {
              tok = appFor "jir" jir;
            };
        }
    );
}
