{
  description = "RPG Horizon build and Scaleway deployment tools";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { nixpkgs, ... }:
    let systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in {
      devShells = nixpkgs.lib.genAttrs systems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          default = pkgs.mkShell {
            packages = [
              pkgs.nodejs_22
              (pkgs.yarn.override { nodejs = pkgs.nodejs_22; })
              pkgs.awscli2 pkgs.opentofu pkgs.scaleway-cli
              pkgs.shellcheck pkgs.actionlint
            ];
          };
        });
    };
}
