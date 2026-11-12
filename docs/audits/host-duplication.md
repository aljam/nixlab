# Host configuration duplication audit

This audit identifies configuration that is repeated across hosts and decides
whether it should be extracted into a shared feature or role module.

## Principles

- Extract only configuration that is genuinely identical across hosts.
- Preserve host-specific differences explicitly.
- Do not create an option solely to toggle one host’s behavior.
- Keep security-sensitive settings explicit rather than hiding them behind
  broad defaults.
- Make one small refactor per follow-up pull request.

## Candidate areas

| Area | Hosts | Current assessment | Proposed action |
|---|---|---|---|
| Log shipping | Previously duplicated | Addressed by PR #389 | No further action unless new duplication appears |
| Common deployment settings | All hosts | Already centralized through `commonModules` | Verify no host overrides duplicate the shared settings |
| Desktop module set | `navi`, `oryx` | Shared through `desktopModules` | Verify no duplicated desktop-only settings remain |
| Disko configuration | `r730`, `r730xd` | Host-specific storage layout | Keep host-specific |
| Mail server configuration | `r820` | Single-host service | Keep host-specific |
| Monitoring exporters | Server hosts | May contain repeated exporter settings | Inventory and extract only identical settings |
| Service-specific secrets | Service hosts | Intentionally service-scoped | Keep service-specific |

## Extraction checklist

Before extracting a repeated block, confirm that:

1. The configuration is semantically identical on every affected host.
2. It does not encode a host-specific security boundary.
3. It does not depend on host-specific hardware, storage, networking, or
   service topology.
4. A shared module makes the resulting configuration easier to reason about.
5. The change can be evaluated and tested independently.

## Follow-up plan

1. Inventory repeated blocks in `hosts/`.
2. Classify each as shared, host-specific, or intentionally duplicated.
3. Extract only clearly shared configuration in small follow-up PRs.
4. Run `nix flake check` and the relevant VM tests after each extraction.
