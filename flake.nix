{
  description = "Secure Podman environment for Claude Code";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

      in {

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            claude-code
            gh
            protobuf
            rustup
          ];
          shellHook = ''
            PS1=$(printf '\n\001\033[1;32m\002[nix develop:\\w]\\$\001\033[0m\002 ')
            export PS1
          '';
        };
      }
    );
}
