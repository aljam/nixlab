# Regression test for the fleet's custom nftables input rules.
#
# This is a pure evaluation check: it reads the rules that each host's
# configuration actually renders into the `input-allow` chain of table
# `inet nixos-fw`, so it needs no VM, no KVM and no root, and it finishes in
# seconds. It is the cheap half of the firewall test pair; tests/firewall.nix
# is the end-to-end half.
#
# The bug it exists to prevent: a rule split across two lines.
#
#   ip saddr 192.168.1.2 tcp dport 9100
#   accept comment "Prometheus node exporter scrape"
#
# nftables allows a rule with no verdict, so this does not fail loudly. The
# first line matches and falls through, and the second becomes an
# unconditional accept that admits every new inbound connection on every port.
{ pkgs, hosts }:

let
  inherit (pkgs) lib;

  verdicts = "accept|drop|reject|return|continue|jump[[:space:]]+[^[:space:]]+|goto[[:space:]]+[^[:space:]]+";

  # A well-formed rule: source-scoped match, then a verdict, then an optional
  # comment. Anything else is either an incomplete rule or too broad to be here.
  wellFormed =
    line:
    builtins.match "[[:space:]]*(ip|ip6)[[:space:]]+saddr[[:space:]]+.*[[:space:]](${verdicts})([[:space:]]+comment[[:space:]]+\"[^\"]*\")?[[:space:]]*" line
    != null;

  # A line whose first token is already a verdict — the failure mode above.
  bareVerdict =
    line: builtins.match "[[:space:]]*(${verdicts})([[:space:]].*)?" line != null;

  isBlank = line: builtins.match "[[:space:]]*" line != null;
  isComment = line: builtins.match "[[:space:]]*#.*" line != null;

  rulesOf =
    cfg: lib.filter (l: !(isBlank l) && !(isComment l)) (lib.splitString "\n" cfg.networking.firewall.extraInputRules);

  # Does any rule mention this port as a standalone number?
  portCovered =
    rules: port:
    lib.any (l: builtins.match ".*[^0-9]${toString port}([^0-9].*|)" l != null) rules;

  checkHost =
    name: node:
    let
      cfg = node.config;
      rules = rulesOf cfg;
      exporter = cfg.services.prometheus.exporters.node;
      backendPorts = cfg.networking.proxyBackendPorts;
      openTCP = cfg.networking.firewall.allowedTCPPorts;
      fail = msg: "${name}: ${msg}";
    in
    # 1. The regression itself: a verdict with nothing to match on.
    map (l: fail "input rule has a verdict but no match, which accepts everything: ${l}") (
      lib.filter bareVerdict rules
    )
    # 2. Every rule must be one complete, source-scoped line.
    ++ map (l: fail "input rule is not a single `ip saddr … <verdict>` line: ${l}") (
      lib.filter (l: !(bareVerdict l) && !(wellFormed l)) rules
    )
    # 3. Backend ports are reachable through the gateway only, never LAN-wide.
    ++ map (p: fail "backend port ${toString p} is in allowedTCPPorts, so it is open to the whole LAN") (
      lib.intersectLists backendPorts openTCP
    )
    # 4. …and each one has to be reachable through the gateway at all.
    ++ map (p: fail "backend port ${toString p} has no input rule, so HAProxy cannot reach it") (
      lib.filter (p: !(portCovered rules p)) backendPorts
    )
    # 5. node_exporter is scraped by the Prometheus server, not by the LAN.
    ++ lib.optional (exporter.enable && lib.elem exporter.port openTCP) (
      fail "node_exporter port ${toString exporter.port} is in allowedTCPPorts"
    )
    ++ lib.optional (exporter.enable && !(portCovered rules exporter.port)) (
      fail "node_exporter is enabled but no input rule allows the Prometheus server to scrape it"
    );

  failures = lib.concatLists (lib.mapAttrsToList checkHost hosts);

  report = lib.concatStrings (
    lib.mapAttrsToList (name: node: ''
      # ${name}
      ${node.config.networking.firewall.extraInputRules}
    '') hosts
  );
in
if failures == [ ] then
  pkgs.writeText "nftables-input-rules-ok" report
else
  throw ''
    nftables input rule check failed:
    ${lib.concatMapStringsSep "\n" (f: "  - ${f}") failures}
  ''
