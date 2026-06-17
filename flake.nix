{
  description = "zellij-tmux-shim — Use Claude Code Agent Teams inside Zellij";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Metadata for the package
      pname = "zellij-tmux-shim";
      version = "0.1.0";
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          default = pkgs.stdenvNoCC.mkDerivation {
            inherit pname version;
            src = ./.;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              runHook preInstall

              mkdir -p $out/bin
              mkdir -p $out/lib/zellij-tmux-shim/bin

              # Install the core scripts
              cp $src/activate.sh   $out/lib/zellij-tmux-shim/activate.sh
              cp $src/deactivate.sh $out/lib/zellij-tmux-shim/deactivate.sh
              cp $src/install.sh    $out/lib/zellij-tmux-shim/install.sh
              cp $src/bin/tmux      $out/lib/zellij-tmux-shim/bin/tmux
              cp $src/bin/zellij-pane-wrapper $out/lib/zellij-tmux-shim/bin/zellij-pane-wrapper

              # Make scripts executable
              chmod +x $out/lib/zellij-tmux-shim/bin/tmux
              chmod +x $out/lib/zellij-tmux-shim/bin/zellij-pane-wrapper
              chmod +x $out/lib/zellij-tmux-shim/activate.sh
              chmod +x $out/lib/zellij-tmux-shim/deactivate.sh
              chmod +x $out/lib/zellij-tmux-shim/install.sh

              # Create a convenience wrapper for activation
              # This sets up the shim for the current shell session
              makeWrapper $out/lib/zellij-tmux-shim/activate.sh $out/bin/zellij-tmux-shim-activate \
                --set ZELLIJ_TMUX_SHIM_DIR "$out/lib/zellij-tmux-shim"

              # Create a convenience wrapper for deactivation
              makeWrapper $out/lib/zellij-tmux-shim/deactivate.sh $out/bin/zellij-tmux-shim-deactivate

              # Create a convenience wrapper for installation to XDG path
              makeWrapper $out/lib/zellij-tmux-shim/install.sh $out/bin/zellij-tmux-shim-install \
                --set SCRIPT_DIR "$out/lib/zellij-tmux-shim"

              runHook postInstall
            '';

            meta = {
              description = "Tmux shim for Claude Code Agent Teams in Zellij";
              homepage = "https://github.com/ogglord/zellij-claude-teams";
              license = pkgs.lib.licenses.mit;
              platforms = pkgs.lib.platforms.all;
              mainProgram = "zellij-tmux-shim-activate";
            };
          };
        };

        # Development shell for working on the shim
        devShells.default = pkgs.mkShell {
          packages = [ pkgs.bash pkgs.zellij ];
          shellHook = ''
            echo "zellij-tmux-shim dev shell"
            echo "zellij: $(zellij --version 2>/dev/null || echo 'not found')"
          '';
        };
      })
    // {
      # Overlays
      overlays.default = final: prev: {
        zellij-tmux-shim = self.packages.${final.system}.default;
      };

      # Home Manager module (optional, for automated shell integration)
      homeManagerModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.zellij-tmux-shim;
        in
        {
          options.programs.zellij-tmux-shim = {
            enable = lib.mkEnableOption "zellij-tmux-shim for Claude Code Agent Teams in Zellij";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.default;
              defaultText = lib.literalExpression "inputs.zellij-claude-teams.packages.\${pkgs.system}.default";
              description = "The zellij-tmux-shim package to use.";
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages = [ cfg.package ];

            # Auto-activate in bash
            programs.bash.initExtra = lib.mkIf config.programs.bash.enable ''
              # --- zellij-tmux-shim (Claude Code Agent Teams in zellij) ---
              if [ -n "$ZELLIJ" ]; then
                export ZELLIJ_TMUX_SHIM_DIR="${cfg.package}/lib/zellij-tmux-shim"
                _shim="${cfg.package}/lib/zellij-tmux-shim/activate.sh"
                [ -f "$_shim" ] && . "$_shim"
                unset _shim
              fi
            '';

            # Auto-activate in zsh
            programs.zsh.initContent = lib.mkIf config.programs.zsh.enable ''
              # --- zellij-tmux-shim (Claude Code Agent Teams in zellij) ---
              if [[ -n "$ZELLIJ" ]]; then
                export ZELLIJ_TMUX_SHIM_DIR="${cfg.package}/lib/zellij-tmux-shim"
                _shim="${cfg.package}/lib/zellij-tmux-shim/activate.sh"
                [[ -f "$_shim" ]] && source "$_shim"
                unset _shim
              fi
            '';
          };
        };
    };
}
