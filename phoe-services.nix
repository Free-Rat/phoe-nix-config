{ config, pkgs, ... }:

let
  phoeNixRoot = builtins.path {
    path = /home/freerat/projects/phoe-nix;
    name = "phoe-nix-source";
  };
  logServiceDefaultEnvPath = "/etc/phoe-nix/log-service.env.defaults";
  logServiceOverrideEnvPath = "/etc/phoe-nix/log-service.env";
  localAgentDefaultEnvPath = "/etc/phoe-nix/local-agent.env.defaults";
  localAgentOverrideEnvPath = "/etc/phoe-nix/local-agent.env";
  logServicePython = pkgs.python311.withPackages (ps: with ps; [
    azure-storage-blob
    pydantic
    systemd
  ]);
  localAgentPython = pkgs.python311.withPackages (ps: with ps; [
    azure-cosmos
    azure-identity
    azure-servicebus
    pydantic
  ]);
  logServiceRunner = pkgs.writeShellApplication {
    name = "phoe-log-service-runner";
    runtimeInputs = [ logServicePython pkgs.systemd ];
    text = ''
      export PYTHONPATH="${phoeNixRoot}/log_service/src"
      exec ${logServicePython}/bin/python -m log_service.main -s sshd
    '';
  };
  localAgentRunner = pkgs.writeShellApplication {
    name = "phoe-local-agent-runner";
    runtimeInputs = [ localAgentPython pkgs.git pkgs.nix pkgs.curl pkgs.coreutils pkgs.bash ];
    text = ''
      export PYTHONPATH="${phoeNixRoot}/local_agent/src:${phoeNixRoot}/schemas/src"
      exec ${localAgentPython}/bin/python -m local_agent.main
    '';
  };
  sharedPath = with pkgs; [
    bash
    coreutils
    curl
    git
    nix
    nixos-rebuild
  ];
in {
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
    CONFIG_REPO_URL=https://github.com/Free-Rat/phoe-nix-config
    CONFIG_REPO_BRANCH=main
    CONFIG_REPO_PATH=/var/lib/phoe-nix-config-repo
    OLLAMA_BASE_URL=http://10.0.2.2:11434
    OLLAMA_MODEL=gemma4:e4b
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
    OLLAMA_BASE_URL=http://10.0.2.2:11434
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
