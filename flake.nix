{
  description = "git-pile scripts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          runtimeInputs = with pkgs; [
            bash
            coreutils
            fzy
            gh
            git
            gnugrep
            gnused
            python3
          ];
        in
        {
          git-pile = pkgs.stdenvNoCC.mkDerivation {
            pname = "git-pile";
            version = "0.0.0";
            src = ./.;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            checkInputs = [ pkgs.shellcheck ];

            installPhase = ''
              runHook preInstall
              mkdir -p "$out/bin"
              cp -r bin/* "$out/bin/"
              chmod +x "$out/bin/"*
              for script in "$out/bin/"*; do
                wrapProgram "$script" --prefix PATH : ${pkgs.lib.makeBinPath runtimeInputs}
              done
              runHook postInstall
            '';

            checkPhase = ''
              runHook preCheck
              shellcheck --severity=error --shell=bash bin/*
              runHook postCheck
            '';

            meta = with pkgs.lib; {
              description = "Stacked-diff workflow scripts for git and GitHub";
              homepage = "https://github.com/keith/git-pile";
              license = licenses.mit;
              platforms = platforms.all;
            };
          };

          default = self.packages.${system}.git-pile;
        });
    };
}
