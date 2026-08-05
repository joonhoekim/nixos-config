{ pkgs, ... }:

# nginx with a declarative package and unit, but an *imperative* config.
#
# Why not services.nginx: the NixOS module builds the whole config from Nix
# expressions into /nix/store and runs `nginx -c /nix/store/...`. That file is
# read-only and a one-line change costs a rebuild. The reason nginx exists on
# this box is to reproduce the reverse proxy in front of the work app's
# closed-network dev/qa servers so that proxy behaviour — WebSocket upgrades,
# static short-circuiting, TLS — can be poked at while developing. Read-only
# config is the opposite of that. The config also already has a single source
# of truth in the app repo (scripts/nginx/configs/<role>/), applied by its own
# deploy-nginx.sh, which backs up, stages, runs `nginx -t` and only then
# reloads — restoring the backup if the test fails.
#
# So the split is:
#   declarative (here) — package, systemd unit, directories, mime.types
#   imperative (/etc/nginx) — nginx.conf, conf.d/*.conf, ssl/*
#
# Apply:   cd <app repo>; bash scripts/nginx/deploy-nginx.sh apply local
# Preview: same script, `diff local`

let
  # Make nginx behave like a distro build.
  #
  # nixpkgs builds nginx without --conf-path, so its default config is
  # <store>/conf/nginx.conf. Debian/RHEL bake in
  # --conf-path=/etc/nginx/nginx.conf, which is why a bare `nginx -t` there
  # checks /etc/nginx. Here it would check the store's stock config and pass —
  # silently defeating the pre-reload safety check in deploy-nginx.sh, which
  # runs exactly that bare `nginx -t` and restores its backup when it fails.
  #
  # Adding -c as a default argument closes the gap. --add-flags puts it before
  # the caller's arguments and nginx honours the last -c it sees, so an
  # explicit `nginx -t -c /somewhere/else.conf` still works.
  #
  # Temp paths need no fixing: nixpkgs points them at /tmp/nginx_* absolutely.
  # Had they been relative to the store prefix, the prefix would have to move
  # too (-p), since the store is read-only.
  nginxEtc = pkgs.symlinkJoin {
    name = "nginx-etc-${pkgs.nginx.version}";
    paths = [ pkgs.nginx ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/nginx --add-flags "-c /etc/nginx/nginx.conf"
    '';
  };
in
{
  environment.systemPackages = [
    nginxEtc

    # Local dev certificates. A mkcert cert is only trusted on the machine
    # whose CA issued it, so one carried in from another box warns here until
    # it is reissued locally.
    pkgs.mkcert
    # certutil, which is how `mkcert -install` reaches a trust store on this
    # system. Its other route — dropping a PEM in /usr/local/share/ca-certificates
    # and running update-ca-certificates — does not exist on NixOS, so without
    # this mkcert generates certificates that nothing ends up trusting.
    #
    # This covers Chrome and Firefox, which read the user NSS database at
    # ~/.pki/nssdb, and that is what local development actually needs.
    # It does *not* cover OpenSSL consumers (curl, node), which read the system
    # bundle. Making those trust it means declaring the CA in
    # security.pki.certificateFiles, which under flakes has to be a path inside
    # this repo — i.e. publishing a trust anchor to a public GitHub repo. Not
    # worth it for `curl -k`; set SSL_CERT_FILE / NODE_EXTRA_CA_CERTS ad hoc if
    # a one-off needs it.
    pkgs.nssTools
  ];

  # Directories the app repo's script writes into. Deliberately not
  # environment.etc: that would make them read-only store symlinks, which is
  # the thing this module exists to avoid. Only the shape is declared; the
  # contents are not.
  #
  # mime.types is the exception — a static asset the config `include`s and
  # nobody edits. Linking it into the store keeps it in step with the package.
  systemd.tmpfiles.rules = [
    "d /etc/nginx 0755 root root -"
    "d /etc/nginx/conf.d 0755 root root -"
    "d /etc/nginx/ssl 0750 root root -"
    "L+ /etc/nginx/mime.types - - - - ${pkgs.nginx}/conf/mime.types"
    # This is the compiled-in --error-log-path. nginx will not start without it.
    "d /var/log/nginx 0755 root root -"
  ];

  systemd.services.nginx = {
    description = "nginx (config in /etc/nginx, not managed declaratively)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    # With no config staged yet, *skip* the unit rather than fail it. Without
    # this, every boot after the first rebuild leaves a failed unit behind for
    # a machine that simply has not been set up yet.
    unitConfig.ConditionPathExists = "/etc/nginx/nginx.conf";

    serviceConfig = {
      Type = "simple";
      # Fail on a syntax error here — the message is far clearer than whatever
      # the start attempt would produce.
      ExecStartPre = "${nginxEtc}/bin/nginx -t";
      # daemon off so systemd tracks the master process directly. Going through
      # a pid file would mean the unit's PIDFile and the `pid` directive in
      # nginx.conf must always agree — and that file is edited by hand, so the
      # coupling is removed instead.
      ExecStart = "${nginxEtc}/bin/nginx -g 'daemon off;'";
      # Same reason: signal the master rather than use `nginx -s reload`, which
      # reads the pid file. deploy-nginx.sh calls `systemctl reload nginx`, so
      # this is the path it takes.
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      # Master stays root to bind 80/443; workers drop to whatever the `user`
      # directive in nginx.conf names.
      #
      # PrivateTmp is left off on purpose — the temp paths are /tmp/nginx_*,
      # and a private /tmp would put them somewhere nothing else can see.
    };
  };

  # The firewall stays shut. Browsers and Playwright reach this over loopback,
  # which NixOS already allows. Add
  #   networking.firewall.allowedTCPPorts = [ 80 443 ];
  # only if another device on the LAN ever needs to reach it.
}
