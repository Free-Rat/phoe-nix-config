{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    phoe-nix-log-service.url = "path:/home/freerat/projects/phoe-nix/log_service";
    phoe-nix-local-agent.url = "path:/home/freerat/projects/phoe-nix/local_agent";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          ./phoe-services.nix
        ];
      };

      vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          ./phoe-services.nix
          {
            virtualisation.vmVariant = {
              virtualisation.memorySize = 4096;
              virtualisation.cores = 4;
              virtualisation.diskSize = 20000;
              virtualisation.graphics = false;
              virtualisation.forwardPorts = [
                {
                  from = "host";
                  host.port = 2222;
                  guest.port = 22;
                }
              ];
            };
          }
        ];
      };
    };

    packages.x86_64-linux.vm = self.nixosConfigurations.vm.config.system.build.vm;
  };
}
