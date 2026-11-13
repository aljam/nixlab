# Dependency vulnerability triage

Use this record to review OSV-Scanner and GitHub Code Scanning findings.
A finding is actionable only when it affects software that is deployed or
reachable from a host.

Do not automatically upgrade a package solely because a scanner reports a
vulnerability. Classify each relevant finding as one of the following:

- `patch`: upgrade or replace the affected component.
- `mitigate`: reduce exposure or impact while an upgrade is unavailable or unsafe.
- `accept`: retain the current version with a documented compensating control and follow-up date.

## Finding template

```markdown
# Dependency vulnerability triage — YYYY-MM-DD

## Finding

- ID: GHSA-xxxx-xxxx-xxxx
- Package: example-package
- Affected version range: < 1.2.3
- Host or service: r730xd
- Deployed: yes/no
- Reachable: yes/no
- Decision: patch / mitigate / accept
- Owner: username
- Follow-up date: YYYY-MM-DD
- Compensating control: network isolation, disabled feature, restricted access, or other control
- Evidence: scanner output, package version, configuration, or advisory link
```

## Required fields

Every accepted or mitigated finding must include:

- A CVE or GHSA identifier.
- The affected package and version range.
- The host or service where the package is deployed.
- Whether the package is deployed and reachable.
- A decision of `patch`, `mitigate`, or `accept`.
- An owner and follow-up date.
- A compensating control or rationale for an accepted risk.

## Review cadence

Review scanner output during the quarterly security review. Re-review accepted
risks at their follow-up date or sooner when the exposure, compensating
control, or upstream advisory changes.

Do not paste secret values, tokens, private keys, or decrypted SOPS contents
into this file or into GitHub issues.
