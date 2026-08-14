{
  description = "Official ChatGPT desktop application packaged for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = package: nixpkgs.lib.getName package == "chatgpt";
      };
      chatgpt = pkgs.callPackage ./package.nix { };
      chatgptApp = {
        type = "app";
        program = "${chatgpt}/bin/chatgpt";
        meta.description = chatgpt.meta.description;
      };
    in
    {
      packages.${system} = {
        default = chatgpt;
        inherit chatgpt;
      };

      apps.${system} = {
        default = chatgptApp;
        chatgpt = chatgptApp;
      };

      checks.${system}.package-smoke =
        pkgs.runCommand "chatgpt-package-smoke"
          {
            nativeBuildInputs = [
              pkgs.desktop-file-utils
              pkgs.patchelf
            ];
          }
          ''
            bash ${./tests/package-smoke.sh} \
              ${chatgpt} \
              ${chatgpt.version} \
              ${pkgs.tectonic-unwrapped.version}
            touch "$out"
          '';

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [
          pkgs.actionlint
          pkgs.curl
          pkgs.dpkg
          pkgs.nixfmt
          pkgs.shellcheck
        ];
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
