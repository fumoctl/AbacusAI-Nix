{
  description = "Abacus AI Desktop and CLI tools (Nix package)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        packages = {
          default = pkgs.callPackage ./pkgs/desktop.nix {};
          abacusai-desktop = pkgs.callPackage ./pkgs/desktop.nix {};
          abacusai-cli = pkgs.callPackage ./pkgs/cli.nix {};
        };

        # Development shell for working on this flake
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nix
            git
            curl
            jq
          ];

          shellHook = ''
            echo "Abacus AI development environment"
            echo "Available commands:"
            echo "  ./scripts/check-version.sh  - Check current vs latest version"
            echo "  ./scripts/update-version.sh - Update to latest version"
          '';
        };
      }
    )
    // {
      # Overlay for easy integration into NixOS configurations
      overlays.default = final: prev: {
        abacusai-desktop = final.callPackage ./pkgs/desktop.nix {};
        abacusai-cli = final.callPackage ./pkgs/cli.nix {};
      };
    };
}
