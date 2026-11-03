# Security review checklist

Use this checklist for a quarterly, dry-run security review. It complements
automated CI, policy assertions, monitoring, and recovery drills; it does not
replace them.

Keep the review simple: record what was checked, what was found, and the
decision made. Do not treat every scanner finding as an incident.

## 1. Dependency vulnerabilities

- [ ] Review recent OSV-Scanner runs and Code Scanning alerts.
- [ ] For each finding, determine whether the affected package is present in a deployed host closure.
- [ ] Classify each relevant finding as `patch`, `mitigate`, or `accept`.
- [ ] Record the CVE/GHSA, affected host or service, decision, owner, and follow-up date.
- [ ] Confirm that accepted risks have a compensating control or documented rationale.

A finding is actionable only when it affects software actually deployed or
reachable from a host. Do not automatically upgrade packages solely because a
scanner reports a vulnerability.

## 2. Secrets and access

- [ ] Compare `.sops.yaml` recipients with the current host inventory and administrator list.
- [ ] Remove recipients for retired hosts, replaced SSH host keys, or users without administrative need.
- [ ] Confirm each secret file has exactly one explicit SOPS creation rule.
- [ ] Confirm no fleet-wide fallback rule exists.
- [ ] Confirm service-specific secrets are not broadly shared across unrelated hosts.
- [ ] Verify that a representative host can decrypt only its intended secret files.

## 3. Host baseline

For each host:

- [ ] Run `systemctl --failed` and `systemctl --user --failed`; investigate failures.
- [ ] Confirm persistent journal logging is enabled and within the configured retention and size limits.
- [ ] Confirm `/var/lib/audit` exists, is root-only, and contains recent audit records.
- [ ] Confirm SSH password authentication, interactive authentication, and direct root login remain disabled.
- [ ] Review recent `sudo`, identity, SSH configuration, and audit-configuration events.
- [ ] Check disk usage, especially on hosts storing media, builds, databases, or container layers.

Useful commands:

```bash
systemctl --failed
systemctl --user --failed
sudo journalctl --disk-usage
sudo ausearch -k sudo-execution --start recent
sudo ausearch -k identity-change --start recent
sudo ausearch -k sshd-config-change --start recent
sudo aureport --auth
df -h
```

## 4. Network exposure

- [ ] Review public ingress and HAProxy backend allowlists.
- [ ] Confirm administrative services such as PostgreSQL, pgAdmin, and Alertmanager are not exposed through the proxy.
- [ ] Confirm services using `servicesBindAddress` do not bind to every interface.
- [ ] Confirm HAProxy backend ports remain unique.
- [ ] Review firewall rules for services that no longer exist or no longer require exposure.
- [ ] Confirm TLS certificates and expiry monitoring are healthy.

## 5. Monitoring and alerting

- [ ] Review active and pending Prometheus alerts.
- [ ] Confirm Alertmanager remains loopback-only.
- [ ] Send a test alert and confirm Ntfy delivery.
- [ ] Confirm warning and critical alerts are grouped and repeat appropriately.
- [ ] Confirm recovery notifications are delivered.

## 6. Backups and recovery

- [ ] Confirm backup jobs completed successfully for every protected dataset.
- [ ] Verify backup retention matches the documented policy.
- [ ] Restore or validate a representative backup; do not rely only on job success.
- [ ] Run the non-decrypting SOPS recovery drill for each host.
- [ ] For a rebuilt or replaced host, confirm its SOPS recipient and decryption access before further deployment.

## 7. Updates and change review

- [ ] Review the latest `flake.lock` diff for NixOS, Home Manager, sops-nix, and hardware-related changes.
- [ ] Run `nix flake check --show-trace` after updates.
- [ ] Trigger full-host CI after merging lockfile changes to `main`.
- [ ] Review OCI image tags and upstream release notes before major container upgrades.
- [ ] Confirm floating container tags remain an intentional tradeoff for timely security fixes.

## 8. Record the outcome

Keep a short dated note for each review:

```markdown
# Security review — YYYY-MM-DD

## Findings

- Finding
- Risk
- Decision: patch / mitigate / accept
- Owner and follow-up date

## Evidence

- CI run links
- Alert or log excerpts
- Backup validation result
```

Store review notes outside the repository if they contain operational details
that should not be public. Do not paste secret values, tokens, private keys,
or decrypted secret contents into notes or issues.
