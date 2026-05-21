{
  description = "Logos Docker image — OCI container built with Nix dockerTools";

  inputs = {
    logos-nix.url = "github:logos-co/logos-nix";
    nixpkgs.follows = "logos-nix/nixpkgs";

    logos-logoscore-cli = {
      url = "github:logos-co/logos-logoscore-cli/454e0696e9417acaac2c0b6dc1f209b5838c7635";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    logos-package-manager = {
      url = "github:logos-co/logos-package-manager/a59f14eb1045df4364d8ce795498ad2e0b323e1e";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    logos-package-downloader = {
      url = "github:logos-co/logos-package-downloader/9f9531b82493b01c3ede0b6b5be04a7422fc6a6e";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    logos-delivery-module = {
      url = "github:logos-co/logos-delivery-module/f461c05";
    };
    logos-storage-module = {
      url = "github:logos-co/logos-storage-module/17ef208";
    };
    logos-blockchain-module = {
      url = "github:logos-blockchain/logos-blockchain-module/6b6a640";
    };
  };

  outputs = { self, nixpkgs, logos-nix, logos-logoscore-cli, logos-package-manager,
              logos-package-downloader, logos-delivery-module,
              logos-storage-module, logos-blockchain-module, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };

          logoscore = logos-logoscore-cli.packages.${system}.cli;
          lgpm = logos-package-manager.packages.${system}.cli;
          lgpd = logos-package-downloader.packages.${system}.cli;

          deliveryModules = logos-delivery-module.packages.${system}.install-portable;
          storageModules = logos-storage-module.packages.${system}.install-portable;
          blockchainModules = logos-blockchain-module.packages.${system}.install-portable;

          mergedModules = pkgs.runCommand "logos-modules" {} ''
            mkdir -p $out/modules
            for src in ${deliveryModules} ${storageModules} ${blockchainModules}; do
              if [ -d "$src/modules" ]; then
                cp -rLn "$src/modules/." "$out/modules/"
              fi
            done
          '';

          image = pkgs.dockerTools.buildLayeredImage {
            name = "logos";
            tag = "latest";
            contents = [ logoscore lgpm lgpd mergedModules pkgs.cacert ];
            config = {
              Cmd = [ "${logoscore}/bin/logoscore" "-D" "-m" "${mergedModules}/modules" ];
              Env = [
                "PATH=${logoscore}/bin:${lgpm}/bin:${lgpd}/bin"
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              ];
            };
          };
        in {
          default = image;
          docker = image;
        }
      );
    };
}
