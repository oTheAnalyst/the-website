{
  description = "A demo of sqlite-web and multiple mysql services";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/x86_64-linux";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";

    services-flake.url = "github:juspay/services-flake";
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import inputs.systems;
      imports = [
        inputs.process-compose-flake.flakeModule
      ];
      perSystem = {
        self',
        pkgs,
        config,
        lib,
        ...
      }: {
        # `process-compose.foo` will add a flake package output called "foo".
        # Therefore, this will add a default package that you can build using
        # `nix build` and run using `nix run`.
        process-compose."bread-oven" = {config, ...}: let
          dbName = "bread";
        in {
          imports = [
            inputs.services-flake.processComposeModules.default
          ];

          services.mysql."m1" = {
            enable = true;
            initialDatabases = [
              {
                name = dbName;
                #schemas = ["${inputs.northwind}/northwind.sql"];
              }
            ];
          };

          # settings.processes.pgweb = let
          #   pgcfg = config.services.mysql.m1;
          # in {
          #   environment.PGWEB_DATABASE_URL = pgcfg.connectionURI {inherit dbName;};
          #   command = pkgs.pgweb;
          #   depends_on."m1".condition = "process_healthy";
          # };
          settings.processes.test = {
            command = pkgs.writeShellApplication {
              name = "m1-test";
              runtimeInputs = [config.services.mysql.m1.package];
              text = ''
              '';
            };
            depends_on."m1".condition = "process_healthy";
          };
        };
        packages.default = self'.packages.bread-oven;
        devShells.default = let
          myPythonPackages = ps:
            with ps; [
              numpy
              pandas
            ];
          pythonEnv = pkgs.python3.withPackages myPythonPackages;
          myRPackages = with pkgs.rPackages; [
            reticulate
            DBI
          ];
        in
          pkgs.mkShell {
            inputsFrom = [
              # Add the packages of the enabled services in the devShell
              #
              # For example: `psql` to interact with `postgres` server or `redis-cli` with `redis-server`
              config.process-compose."bread-oven".services.outputs.devShell
            ];
            packages = with pkgs; [
              # Add the process-compose app in the devShell
              cowsay
              dbeaver-bin
              pnpm
              nodejs_24
              mariadb
              sqlfluff
              duckdb
              texliveSmall
              ((quarto.override {
                  extraPythonPackages = myPythonPackages;
                  extraRPackages = myRPackages;
                }).overrideAttrs (oldAttrs: {
                  # Remove this overrideAttrs patch when fixed.
                  # See https://github.com/NixOS/nixpkgs/issues/519484#issuecomment-4667477454
                  postPatch =
                    (oldAttrs.postPatch or "")
                    + ''
                      substituteInPlace bin/quarto.js \
                        --replace-fail "syntax-highlighting" "highlight-style"
                    '';
                }))
              (rWrapper.override {packages = myRPackages;})
              pythonEnv
              #
              # In the devShell, run `bread-oven` to run the app
              self'.packages.bread-oven
            ];
            shellHook = ''
              echo "Looks like you comleted the flake services new build" |
              echo "Quickstart: run 'quarto render document.qmd'" |
                cowsay
            '';
            nativeBuildInputs = [pkgs.just];
          };
      };
    };
}
