{ config, pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  logServiceDefaultEnvPath = "/etc/phoe-nix/log-service.env.defaults";
  logServiceOverrideEnvPath = "/etc/phoe-nix/log-service.env";
  localAgentDefaultEnvPath = "/etc/phoe-nix/local-agent.env.defaults";
  localAgentOverrideEnvPath = "/etc/phoe-nix/local-agent.env";
  githubKnownHostsPath = "/etc/phoe-nix/github-known_hosts";
  localAgentRepoKeyPath = "/var/lib/phoe-nix-secrets/local-agent-repo-key";
  localAgentGitSshCommand = "ssh -i ${localAgentRepoKeyPath} -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${githubKnownHostsPath}";
  rebuildTarget = "/var/lib/phoe-nix-config-repo#simulation";
  rebuildCommand = ''NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild test --flake ${rebuildTarget} --impure'';
  logServicePackage = inputs.phoe-nix-log-service.packages.${system}.default;
  localAgentPackage = inputs.phoe-nix-local-agent.packages.${system}.default;
  logServiceRunner = pkgs.writeShellApplication {
    name = "phoe-log-service-runner";
    runtimeInputs = [ logServicePackage pkgs.systemd ];
    text = ''
      exec ${logServicePackage}/bin/log_service -s sshd
    '';
  };
  localAgentRunner = pkgs.writeShellApplication {
    name = "phoe-local-agent-runner";
    runtimeInputs = [ localAgentPackage pkgs.git pkgs.nix pkgs.curl pkgs.coreutils pkgs.bash pkgs.openssh ];
    text = ''
      exec ${localAgentPackage}/bin/local_agent
    '';
  };
  sharedPath = with pkgs; [
    bash
    coreutils
    curl
    git
    nix
    nixos-rebuild
    openssh
  ];
in {
  environment.etc."phoe-nix/github-known_hosts".text = ''
    github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
  '';

  environment.etc."phoe-nix/log-service.env.defaults".text = ''
    TOKEN_SERVICE_URL=http://127.0.0.1:9999/api/token
    SPOOL_DIRECTORY=/var/lib/phoe-nix-log-service
    NODE_API_KEY=
  '';

  environment.etc."phoe-nix/log-service.env.example".text = ''
    # Copy values you want to override into /etc/phoe-nix/log-service.env.
    TOKEN_SERVICE_URL=https://your-token-service.example/api/token
    NODE_API_KEY=
  '';

  environment.etc."phoe-nix/local-agent.env.defaults".text = ''
    SERVICEBUS_ENABLED=0
    SERVICEBUS_CONNECTION=
    COSMOSDB_ENABLED=0
    COSMOSDB_ENDPOINT=
    COSMOSDB_KEY=
    COSMOSDB_DATABASE_NAME=project-healer
    CONFIG_REPO_URL=git@github.com:Free-Rat/phoe-nix-config.git
    CONFIG_REPO_BRANCH=main
    CONFIG_REPO_PATH=/var/lib/phoe-nix-config-repo
    GIT_SSH_COMMAND='${localAgentGitSshCommand}'
    REBUILD_TEST_COMMAND='${rebuildCommand}'
    REBUILD_SWITCH_COMMAND='${rebuildCommand}'
    OLLAMA_BASE_URL=http://10.0.2.2:11434
    OLLAMA_MODEL=gpt-oss:20b
    OBSERVE_INTERVAL_SECONDS=10
    REPO_REFRESH_SECONDS=300
  '';

  environment.etc."phoe-nix/local-agent.env.example".text = ''
    # Copy values you want to override into /etc/phoe-nix/local-agent.env.
    SERVICEBUS_ENABLED=1
    SERVICEBUS_CONNECTION=Endpoint=sb://your-namespace.servicebus.windows.net/;SharedAccessKeyName=...;SharedAccessKey=...
    COSMOSDB_ENABLED=1
    COSMOSDB_ENDPOINT=https://your-account.documents.azure.com:443/
    # Leave COSMOSDB_KEY empty when using managed identity or other DefaultAzureCredential sources.
    COSMOSDB_KEY=
    COSMOSDB_DATABASE_NAME=project-healer
    CONFIG_REPO_URL=git@github.com:Free-Rat/phoe-nix-config.git
    CONFIG_REPO_BRANCH=main
    CONFIG_REPO_PATH=/var/lib/phoe-nix-config-repo
    GIT_SSH_COMMAND='${localAgentGitSshCommand}'
    REBUILD_TEST_COMMAND='${rebuildCommand}'
    REBUILD_SWITCH_COMMAND='${rebuildCommand}'
    OLLAMA_BASE_URL=http://10.0.2.2:11434
    OLLAMA_MODEL=gpt-oss:20b
  '';

  environment.etc."phoe-nix/local-agent-repo-key.example".text = ''
    Install a GitHub deploy key private key at ${localAgentRepoKeyPath} with mode 0600.
    The matching public key should be registered as a write-enabled deploy key on phoe-nix-config.
  '';

  environment.systemPackages = [
    logServiceRunner
    localAgentRunner
  ];

  systemd.services.log_service = {
    description = "Phoe-nix log_service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${logServiceRunner}/bin/phoe-log-service-runner";
      Restart = "always";
      RestartSec = 5;
      EnvironmentFile = [
        logServiceDefaultEnvPath
        "-${logServiceOverrideEnvPath}"
      ];
      Environment = [
        "NODE_ID=${config.networking.hostName}"
      ];
      StateDirectory = "phoe-nix-log-service";
    };
    path = sharedPath;
  };

  systemd.services.local_agent = {
    description = "Phoe-nix local_agent";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${localAgentRunner}/bin/phoe-local-agent-runner";
      Restart = "always";
      RestartSec = 5;
      EnvironmentFile = [
        localAgentDefaultEnvPath
        "-${localAgentOverrideEnvPath}"
      ];
      Environment = [
        "LOCAL_AGENT_RUN_MODE=daemon"
        "NODE_ID=${config.networking.hostName}"
      ];
      StateDirectory = "phoe-nix-config-repo";
    };
    path = sharedPath;
  };
}
