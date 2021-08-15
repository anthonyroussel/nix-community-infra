{ config, pkgs, lib, ... }:
let
  configFile = "/var/lib/post-build-hook/nix-community-cachix.dhall";
  sources = import ../nix/sources.nix {};
in
{
  systemd.services.cachix-watch-store = {
    description = "Cachix store watcher service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = [ config.nix.package ];
    # either cachix or nix want that
    environment.XDG_CACHE_HOME = "/var/cache/cachix-watch-store";
    serviceConfig = {
      Type = "notify";
      Restart = "always";
      CacheDirectory = "cachix-watch-store";
      ExecStart = "${import sources.cachix {}}/bin/cachix -c ${configFile} watch-store nix-community";
    };
  };
  systemd.services.nix-gc.serviceConfig = lib.mkIf (config.services.hydra.enable) {
    # This hopefully drains the upload queue to avoid nix-gc beeing faster than cachix uploading derivations
    # Otherwise we might run into https://github.com/cachix/cachix/issues/370
    ExecStartPre = [
      "${pkgs.systemd}/bin/systemctl stop hydra-queue-runner.service"
      "${pkgs.systemd}/bin/systemctl stop cachix-watch-store.service"
    ];
    TimeoutStartSec = "11min";
    ExecStopPost = "${pkgs.systemd}/bin/systemctl start hydra-queue-runner.service cachix-watch-store.service";
  };
}
